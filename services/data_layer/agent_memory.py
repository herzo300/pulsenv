from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.orm import Session

from services.data_layer.models import AgentFact, AgentJob, AgentMessage, AgentThread, AgentToolLog


def _utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def _dumps(payload: Any) -> str | None:
    if payload is None:
        return None
    return json.dumps(
        payload, ensure_ascii=False, separators=(",", ":"), sort_keys=True
    )


def _loads(payload: str | None) -> Any:
    if not payload:
        return {}
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return payload


def ensure_thread(
    db: Session,
    *,
    thread_id: int | None,
    source: str,
    scope: str,
    task_type: str,
    title: str,
    metadata: dict[str, Any] | None = None,
) -> AgentThread:
    thread = None
    if thread_id is not None:
        thread = db.query(AgentThread).filter(AgentThread.id == thread_id).first()
    if thread is not None:
        thread.updated_at = _utcnow()
        db.add(thread)
        db.flush()
        return thread

    thread = AgentThread(
        source=source,
        scope=scope,
        task_type=task_type,
        title=title[:200],
        status="open",
        metadata_json=_dumps(metadata or {}),
    )
    db.add(thread)
    db.flush()
    return thread


def create_message(
    db: Session,
    *,
    thread_id: int,
    role: str,
    content: str | None,
    structured_payload: Any = None,
    model: str | None = None,
    usage: dict[str, Any] | None = None,
) -> AgentMessage:
    usage = usage or {}
    message = AgentMessage(
        thread_id=thread_id,
        role=role,
        content=content,
        structured_payload=_dumps(structured_payload),
        model=model,
        prompt_tokens=usage.get("prompt_tokens"),
        completion_tokens=usage.get("completion_tokens"),
        total_tokens=usage.get("total_tokens"),
    )
    db.add(message)
    db.flush()
    return message


def create_job(
    db: Session,
    *,
    thread_id: int,
    job_type: str,
    priority: str,
    context: dict[str, Any] | None = None,
) -> AgentJob:
    job = AgentJob(
        thread_id=thread_id,
        job_type=job_type,
        priority=priority,
        status="running",
        context_json=_dumps(context or {}),
        started_at=_utcnow(),
    )
    db.add(job)
    db.flush()
    return job


def finish_job(
    db: Session,
    job: AgentJob,
    *,
    status: str,
    result_summary: str | None = None,
    error_text: str | None = None,
) -> AgentJob:
    job.status = status
    job.result_summary = result_summary
    job.error_text = error_text
    job.finished_at = _utcnow()
    db.add(job)
    db.flush()

    thread = db.query(AgentThread).filter(AgentThread.id == job.thread_id).first()
    if thread is not None:
        thread.status = "completed" if status == "completed" else "failed"
        thread.updated_at = _utcnow()
        db.add(thread)
        db.flush()
    return job


def log_tool_call(
    db: Session,
    *,
    thread_id: int,
    job_id: int | None,
    tool_name: str,
    input_summary: str | None,
    output_summary: str | None,
    latency_ms: int | None,
    success: bool,
) -> AgentToolLog:
    tool_log = AgentToolLog(
        thread_id=thread_id,
        job_id=job_id,
        tool_name=tool_name,
        input_summary=input_summary,
        output_summary=output_summary,
        latency_ms=latency_ms,
        success=success,
    )
    db.add(tool_log)
    db.flush()
    return tool_log


def add_fact(
    db: Session,
    *,
    thread_id: int,
    fact_key: str,
    fact_value: Any,
    confidence: float = 0.0,
) -> AgentFact:
    fact = AgentFact(
        thread_id=thread_id,
        fact_key=fact_key[:120],
        fact_value=_dumps(fact_value) or "",
        confidence=confidence,
    )
    db.add(fact)
    db.flush()
    return fact


def serialize_thread(thread: AgentThread) -> dict[str, Any]:
    return {
        "id": thread.id,
        "source": thread.source,
        "scope": thread.scope,
        "task_type": thread.task_type,
        "title": thread.title,
        "status": thread.status,
        "metadata": _loads(thread.metadata_json),
        "created_at": thread.created_at,
        "updated_at": thread.updated_at,
    }


def serialize_message(message: AgentMessage) -> dict[str, Any]:
    return {
        "id": message.id,
        "thread_id": message.thread_id,
        "role": message.role,
        "content": message.content,
        "structured_payload": _loads(message.structured_payload),
        "model": message.model,
        "prompt_tokens": message.prompt_tokens,
        "completion_tokens": message.completion_tokens,
        "total_tokens": message.total_tokens,
        "created_at": message.created_at,
    }


def serialize_job(job: AgentJob) -> dict[str, Any]:
    return {
        "id": job.id,
        "thread_id": job.thread_id,
        "job_type": job.job_type,
        "priority": job.priority,
        "status": job.status,
        "context": _loads(job.context_json),
        "result_summary": job.result_summary,
        "error_text": job.error_text,
        "started_at": job.started_at,
        "finished_at": job.finished_at,
        "created_at": job.created_at,
    }


def get_thread_or_none(db: Session, thread_id: int) -> AgentThread | None:
    return db.query(AgentThread).filter(AgentThread.id == thread_id).first()


def list_thread_messages(db: Session, thread_id: int) -> list[AgentMessage]:
    return (
        db.query(AgentMessage)
        .filter(AgentMessage.thread_id == thread_id)
        .order_by(AgentMessage.created_at.asc(), AgentMessage.id.asc())
        .all()
    )


def list_jobs(db: Session, *, limit: int) -> list[AgentJob]:
    return (
        db.query(AgentJob)
        .order_by(AgentJob.created_at.desc(), AgentJob.id.desc())
        .limit(limit)
        .all()
    )
