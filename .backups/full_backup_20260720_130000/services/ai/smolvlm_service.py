# services/smolvlm_service.py
"""
Local Vision-Language analysis for city camera frames.

Primary: Gemma 4 E4B via Ollama/LiteLLM (multimodal, ~4B params).
Legacy fallback: SmolVLM-256M via llama.cpp server.

Gemma 4 provides dramatically better scene understanding than SmolVLM-256M
while still running locally on the Timeweb server.
Стоимость: 0₽.
"""

import base64
import json
import logging
import os
import re
from typing import Any

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


def _candidate_urls() -> list[str]:
    explicit = (os.getenv("SMOLVLM_URL", "") or "").strip().rstrip("/")
    candidates: list[str] = []
    if explicit:
        candidates.append(explicit)

    defaults = [
        "http://127.0.0.1:8090",
        "http://localhost:8090",
        "http://host.docker.internal:8090",
        "http://smolvlm:8090",
    ]
    for value in defaults:
        if value not in candidates:
            candidates.append(value)
    return candidates


SMOLVLM_URLS: list[str] = _candidate_urls()
SMOLVLM_URL: str = SMOLVLM_URLS[0]
SMOLVLM_ENABLED: bool = os.getenv("SMOLVLM_ENABLED", "true").lower() == "true"
SMOLVLM_TIMEOUT: int = int(os.getenv("SMOLVLM_TIMEOUT", "30"))
_active_smolvlm_url: str | None = None

# Qwen Vision via Ollama/LiteLLM (primary)
QWEN_VISION_MODEL: str = os.getenv("QWEN_VISION_MODEL", "qwen2.5vl:3b").strip()
QWEN_VISION_ENABLED: bool = os.getenv("QWEN_VISION_ENABLED", "true").lower() == "true"

# LiteLLM endpoint candidates
_LITELLM_URLS: list[str] = []
for _url in (
    os.getenv("LITELLM_URL", "http://litellm:4000"),
    "http://litellm:4000",
    "http://127.0.0.1:4000",
):
    _u = (_url or "").strip().rstrip("/")
    if _u and _u not in _LITELLM_URLS:
        _LITELLM_URLS.append(_u)
_LITELLM_KEY: str = os.getenv("LITELLM_MASTER_KEY", "").strip()

# Ollama direct endpoints
_OLLAMA_URLS: list[str] = []
for _url in (
    os.getenv("OLLAMA_URL", "http://ollama:11434"),
    "http://ollama:11434",
    "http://127.0.0.1:11434",
):
    _u = (_url or "").strip().rstrip("/")
    if _u and _u not in _OLLAMA_URLS:
        _OLLAMA_URLS.append(_u)

# Промпт для анализа камер
VISION_PROMPT = (
    "Analyze this city surveillance camera image. "
    "Is there a problem? Types: dump (garbage), accident (car crash), "
    "flood (water), smoke (fire/smoke), animals (stray dogs 3+), none (normal). "
    'Return ONLY JSON: {"event_type":"none|dump|accident|flood|smoke|animals",'
    '"confidence":0.0-1.0,"description":"brief description or null"}'
)


async def _check_health() -> bool:
    """Check if SmolVLM server is running."""
    global _active_smolvlm_url
    from core.http_client import get_http_client

    for base_url in SMOLVLM_URLS:
        try:
            async with get_http_client(timeout=3.0, proxy=False) as client:
                r = await client.get(f"{base_url}/health")
                if r.status_code == 200:
                    _active_smolvlm_url = base_url
                    return True
        except Exception:
            continue
    return False


async def _analyze_via_qwen(image_bytes: bytes) -> dict[str, Any] | None:
    """Analyze image via Qwen through LiteLLM or Ollama directly."""
    from core.http_client import get_http_client

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    payload = {
        "model": "qwen-vision",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": VISION_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "temperature": 0.1,
        "max_tokens": 200,
    }
    headers = {"Content-Type": "application/json"}
    if _LITELLM_KEY:
        headers["Authorization"] = f"Bearer {_LITELLM_KEY}"

    # Try LiteLLM first, then Ollama directly
    for base_url in _LITELLM_URLS:
        try:
            async with get_http_client(timeout=60.0, proxy=False) as client:
                r = await client.post(
                    f"{base_url}/chat/completions",
                    json=payload,
                    headers=headers,
                )
                if r.status_code != 200:
                    logger.debug(
                        "Gemma4 vision via %s HTTP %d", base_url, r.status_code
                    )
                    continue
                content = (
                    r.json()
                    .get("choices", [{}])[0]
                    .get("message", {})
                    .get("content", "")
                )
                if content:
                    result = _parse_json(content)
                    if result:
                        logger.info(
                            "Gemma4 vision: event=%s conf=%.2f",
                            result.get("event_type"),
                            result.get("confidence", 0),
                        )
                        return result
        except Exception as e:
            logger.debug("Gemma4 vision via %s error: %s", base_url, e)

    # Direct Ollama fallback
    ollama_payload = {
        "model": QWEN_VISION_MODEL,
        "messages": payload["messages"],
        "temperature": 0.1,
        "stream": False,
    }
    for base_url in _OLLAMA_URLS:
        try:
            async with get_http_client(timeout=60.0, proxy=False) as client:
                r = await client.post(
                    f"{base_url}/api/chat",
                    json=ollama_payload,
                )
                if r.status_code != 200:
                    continue
                content = r.json().get("message", {}).get("content", "")
                if content:
                    result = _parse_json(content)
                    if result:
                        return result
        except Exception as e:
            logger.debug("Gemma4 vision Ollama(%s) error: %s", base_url, e)

    return None


async def analyze_image_local(image_bytes: bytes) -> dict[str, Any] | None:
    """
    Analyze image using local AI models.

    Priority:
    1. Gemma 4 E4B via LiteLLM/Ollama (best quality, multimodal)
    2. SmolVLM-256M via llama.cpp (legacy fallback)

    Returns: {event_type, confidence, description} or None.
    """
    if not SMOLVLM_ENABLED and not QWEN_VISION_ENABLED:
        return None

    # 1. Try Qwen first
    if QWEN_VISION_ENABLED:
        result = await _analyze_via_qwen(image_bytes)
        if result:
            return result

    # 2. Legacy SmolVLM fallback
    if not SMOLVLM_ENABLED:
        return None

    if not await _check_health():
        logger.debug("SmolVLM not available, skipping local analysis")
        return None

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    payload = {
        "model": "smolvlm",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": VISION_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "temperature": 0.1,
        "max_tokens": 200,
    }

    from core.http_client import get_http_client

    for base_url in SMOLVLM_URLS:
        try:
            async with get_http_client(
                timeout=float(SMOLVLM_TIMEOUT), proxy=False
            ) as client:
                r = await client.post(
                    f"{base_url}/v1/chat/completions",
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )

                if r.status_code != 200:
                    logger.warning(
                        "SmolVLM %s HTTP %d: %s", base_url, r.status_code, r.text[:200]
                    )
                    continue

                data = r.json()
                content = (
                    data.get("choices", [{}])[0].get("message", {}).get("content", "")
                )

                if not content:
                    continue

                return _parse_json(content)
        except Exception as e:
            logger.warning("SmolVLM error via %s: %s", base_url, e)
    return None


def _parse_json(text: str) -> dict[str, Any] | None:
    """Parse JSON from LLM response (handles markdown fences)."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            try:
                return json.loads(m.group())
            except json.JSONDecodeError:
                pass
    return None


async def get_status() -> dict[str, Any]:
    """Vision service status for admin panel."""
    smolvlm_healthy = await _check_health()
    return {
        "qwen_vision_enabled": QWEN_VISION_ENABLED,
        "qwen_vision_model": QWEN_VISION_MODEL,
        "smolvlm_enabled": SMOLVLM_ENABLED,
        "smolvlm_url": SMOLVLM_URL,
        "smolvlm_candidates": SMOLVLM_URLS,
        "smolvlm_active_url": _active_smolvlm_url,
        "smolvlm_healthy": smolvlm_healthy,
        "timeout": SMOLVLM_TIMEOUT,
    }
