from __future__ import annotations

import json
import logging
import os
import time
from typing import Any

from sqlalchemy.orm import Session

from core.http_client import get_http_client
from services.ai.agent_memory import (
    add_fact,
    create_job,
    create_message,
    ensure_thread,
    finish_job,
    log_tool_call,
)
from services.ai.agent_schemas import (
    AgentRunRequest,
    AgentRunResponse,
    AgentRunResult,
    AgentToolCall,
)
from services.ai.agent_tools import ALLOWED_TOOLS, run_tool
from services.ai.zai_service import LITELLM_MASTER_KEY, LITELLM_TEXT_MODEL, LITELLM_URLS

logger = logging.getLogger(__name__)

AGENT_ALLOWED_ACTIONS = ("analyze", "summarize", "classify", "notify")
AGENT_MAX_TOOL_CALLS = max(0, int(os.getenv("AGENT_MAX_TOOL_CALLS", "3")))
AGENT_TIMEOUT_SECONDS = max(5.0, float(os.getenv("AGENT_TIMEOUT_SECONDS", "60")))
AGENT_RETRIES = max(0, int(os.getenv("AGENT_RETRIES", "1")))
AGENT_LLM_BASE_URL = (
    (
        os.getenv("AGENT_LLM_BASE_URL")
        or os.getenv("OPENAI_BASE_URL")
        or (LITELLM_URLS[0] if LITELLM_URLS else "http://127.0.0.1:4000")
    )
    .strip()
    .rstrip("/")
)
AGENT_LLM_MODEL = (
    os.getenv("AGENT_LLM_MODEL") or LITELLM_TEXT_MODEL or "qwen-mini"
).strip()
AGENT_LLM_API_KEY = (
    os.getenv("AGENT_LLM_API_KEY")
    or os.getenv("openrouter_api_key")
    or os.getenv("OPENROUTER_API_KEY")
    or os.getenv("GEMMA_CLOUD_API_KEY")
    or os.getenv("OPENAI_API_KEY")
    or LITELLM_MASTER_KEY
).strip()
AGENT_VISION_MODEL = (os.getenv("AGENT_VISION_MODEL") or AGENT_LLM_MODEL).strip()


def _normalize_base_url(value: str) -> str:
    value = value.strip().rstrip("/")
    if not value:
        return "http://127.0.0.1:4000/v1"
    if value.endswith("/v1"):
        return value
    return f"{value}/v1"


def _trim_text(value: Any, limit: int = 800) -> str:
    text = str(value or "").strip()
    if len(text) <= limit:
        return text
    return text[: limit - 3].rstrip() + "..."


def _system_prompt(task_type: str) -> str:
    return (
        "You are the Pulse City agent for the «Пульс города» platform. "
        "Use only the provided context and tool outputs. "
        "Return valid JSON with keys: result, confidence, notes, facts. "
        f"Current action class: {task_type}. "
        f"Allowed action classes: {', '.join(AGENT_ALLOWED_ACTIONS)}. "
        "Do not invent tool calls or claim external side effects."
    )


def _build_messages(
    request: AgentRunRequest, tool_results: dict[str, Any]
) -> list[dict[str, Any]]:
    context_json = json.dumps(request.context, ensure_ascii=False, sort_keys=True)
    tools_json = json.dumps(tool_results, ensure_ascii=False, sort_keys=True)
    text_payload = (
        f"Prompt:\n{request.prompt}\n\n"
        f"Context:\n{context_json}\n\n"
        f"Tool results:\n{tools_json}\n\n"
        "Respond with JSON only."
    )
    if request.image_url or request.image_base64:
        image_url = request.image_url or request.image_base64
        return [
            {"role": "system", "content": _system_prompt(request.task_type)},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": text_payload},
                    {"type": "image_url", "image_url": {"url": image_url}},
                ],
            },
        ]
    return [
        {"role": "system", "content": _system_prompt(request.task_type)},
        {"role": "user", "content": text_payload},
    ]


def _extract_content(payload: dict[str, Any]) -> str:
    try:
        content = payload["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(
            "LLM response did not include choices[0].message.content"
        ) from exc
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(str(item.get("text") or ""))
            elif isinstance(item, str):
                parts.append(item)
        return "".join(parts).strip()
    return str(content or "").strip()


def _extract_usage(payload: dict[str, Any]) -> dict[str, Any]:
    usage = payload.get("usage") or {}
    return {
        "prompt_tokens": usage.get("prompt_tokens"),
        "completion_tokens": usage.get("completion_tokens"),
        "total_tokens": usage.get("total_tokens"),
    }


def _parse_agent_output(content: str) -> dict[str, Any]:
    text = content.strip()
    if not text:
        return {"result": None, "confidence": 0.0, "notes": [], "facts": {}}
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return {"result": text, "confidence": 0.5, "notes": [], "facts": {}}
    if not isinstance(parsed, dict):
        return {"result": parsed, "confidence": 0.5, "notes": [], "facts": {}}
    return {
        "result": parsed.get("result", parsed),
        "confidence": float(parsed.get("confidence") or 0.0),
        "notes": parsed.get("notes") or [],
        "facts": parsed.get("facts") or {},
    }


async def _call_chat_completion(
    request: AgentRunRequest, tool_results: dict[str, Any]
) -> dict[str, Any]:
    payload = {
        "model": AGENT_VISION_MODEL
        if (request.image_url or request.image_base64)
        else AGENT_LLM_MODEL,
        "messages": _build_messages(request, tool_results),
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    headers = {"Content-Type": "application/json"}
    if AGENT_LLM_API_KEY:
        headers["Authorization"] = f"Bearer {AGENT_LLM_API_KEY}"

    target_url = f"{_normalize_base_url(AGENT_LLM_BASE_URL)}/chat/completions"
    last_error: Exception | None = None
    for _ in range(AGENT_RETRIES + 1):
        try:
            async with get_http_client(
                timeout=AGENT_TIMEOUT_SECONDS, proxy=False
            ) as client:
                response = await client.post(target_url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
            return {
                "content": _extract_content(data),
                "usage": _extract_usage(data),
                "model": data.get("model") or payload["model"],
                "provider": "openai-compatible",
                "raw": data,
            }
        except Exception as exc:  # pragma: no cover - network dependent
            last_error = exc
    raise RuntimeError(f"Agent model call failed: {last_error}") from last_error


async def run_agent_task(db: Session, request: AgentRunRequest) -> AgentRunResponse:
    metadata = {
        "tools": request.tools,
        "has_image": bool(request.image_url or request.image_base64),
    }
    thread = ensure_thread(
        db,
        thread_id=request.thread_id,
        source=request.source,
        scope=request.scope,
        task_type=request.task_type,
        title=_trim_text(request.prompt, 200),
        metadata=metadata,
    )
    job = create_job(
        db,
        thread_id=thread.id,
        job_type=request.task_type,
        priority=request.priority,
        context=request.context,
    )
    create_message(
        db,
        thread_id=thread.id,
        role="user",
        content=request.prompt,
        structured_payload={
            "context": request.context,
            "tools": request.tools,
            "image_url": request.image_url,
            "has_image_base64": bool(request.image_base64),
        },
    )
    db.commit()

    tool_calls: list[AgentToolCall] = []
    tool_results: dict[str, Any] = {}
    try:
        requested_tools = [name for name in request.tools if name in ALLOWED_TOOLS][
            :AGENT_MAX_TOOL_CALLS
        ]
        for tool_name in requested_tools:
            tool_input = request.tool_inputs.get(tool_name) or {}
            started = time.perf_counter()
            success = False
            output_summary = ""
            try:
                result = run_tool(tool_name, tool_input, db)
                tool_results[tool_name] = result
                output_summary = _trim_text(
                    json.dumps(result, ensure_ascii=False, sort_keys=True), 500
                )
                success = True
            finally:
                latency_ms = int((time.perf_counter() - started) * 1000)
                log_tool_call(
                    db,
                    thread_id=thread.id,
                    job_id=job.id,
                    tool_name=tool_name,
                    input_summary=_trim_text(
                        json.dumps(tool_input, ensure_ascii=False, sort_keys=True), 300
                    ),
                    output_summary=output_summary,
                    latency_ms=latency_ms,
                    success=success,
                )
                tool_calls.append(
                    AgentToolCall(
                        name=tool_name,
                        input_summary=_trim_text(
                            json.dumps(tool_input, ensure_ascii=False, sort_keys=True),
                            300,
                        ),
                        output_summary=output_summary or None,
                        success=success,
                        latency_ms=latency_ms,
                    )
                )
        completion = await _call_chat_completion(request, tool_results)
        parsed = _parse_agent_output(completion["content"])
        facts = parsed.get("facts") or {}
        if isinstance(facts, dict):
            for fact_key, fact_value in facts.items():
                add_fact(
                    db,
                    thread_id=thread.id,
                    fact_key=str(fact_key),
                    fact_value=fact_value,
                    confidence=float(parsed.get("confidence") or 0.0),
                )

        create_message(
            db,
            thread_id=thread.id,
            role="assistant",
            content=completion["content"],
            structured_payload=parsed,
            model=completion.get("model"),
            usage=completion.get("usage"),
        )
        runtime = AgentRunResult(
            status="completed",
            result=parsed.get("result"),
            confidence=float(parsed.get("confidence") or 0.0),
            notes=list(parsed.get("notes") or []),
            tool_calls=tool_calls,
            errors=[],
            provider=completion.get("provider"),
            model=completion.get("model"),
        )
        finish_job(
            db,
            job,
            status="completed",
            result_summary=_trim_text(
                json.dumps(parsed.get("result"), ensure_ascii=False), 500
            ),
        )
        db.commit()
        return AgentRunResponse(thread_id=thread.id, job_id=job.id, runtime=runtime)
    except Exception as exc:
        logger.warning(
            "Agent task failed for thread %s job %s: %s", thread.id, job.id, exc
        )
        runtime = AgentRunResult(
            status="failed",
            result=None,
            confidence=0.0,
            notes=[],
            tool_calls=tool_calls,
            errors=[str(exc)],
            provider="openai-compatible",
            model=AGENT_VISION_MODEL
            if (request.image_url or request.image_base64)
            else AGENT_LLM_MODEL,
        )
        create_message(
            db,
            thread_id=thread.id,
            role="assistant",
            content=None,
            structured_payload=runtime.model_dump(),
            model=runtime.model,
        )
        finish_job(db, job, status="failed", error_text=str(exc))
        db.commit()
        return AgentRunResponse(thread_id=thread.id, job_id=job.id, runtime=runtime)
