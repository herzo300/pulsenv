"""Event-driven agent worker for city info board integration.

Receives events from public sources, monitoring scripts, or scheduled
tasks and dispatches them to the agent runtime for analysis.
"""

from __future__ import annotations

import json
import logging
import time
from datetime import UTC, datetime
from typing import Any

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from services.ai.agent_runtime import run_agent_task
from services.ai.agent_schemas import AgentRunRequest

logger = logging.getLogger(__name__)

# Recent event keys for deduplication (in-memory, resets on restart).
_recent_events: dict[str, float] = {}
_DEDUP_WINDOW_SECONDS = 300  # 5 minutes


class AgentEvent(BaseModel):
    """Incoming event payload from external systems."""

    event_type: str = Field(min_length=1, max_length=80)
    source: str = Field(default="webhook", max_length=80)
    source_id: str | None = Field(default=None, max_length=200)
    data: dict[str, Any] = Field(default_factory=dict)
    image_url: str | None = Field(default=None, max_length=4000)
    priority: str = Field(default="normal", pattern="^(low|normal|high)$")


class AgentEventResponse(BaseModel):
    """Response after event processing."""

    accepted: bool
    deduplicated: bool = False
    thread_id: int | None = None
    job_id: int | None = None
    error: str | None = None


# --- Event type to agent task mapping ---

_EVENT_TASK_MAP: dict[str, dict[str, Any]] = {
    "daily_digest": {
        "task_type": "summarize",
        "prompt_template": (
            "Summarize daily city pulse data. "
            "Reports: {report_count}. Categories: {categories}. "
            "Date: {date}. Additional data: {extra}"
        ),
        "tools": ["report_lookup", "opendata_lookup"],
        "scope": "digest",
    },
    "opendata_anomaly": {
        "task_type": "analyze",
        "prompt_template": (
            "Analyse open data anomaly. Dataset: {dataset}. "
            "Anomaly: {anomaly}. Data: {extra}"
        ),
        "tools": ["opendata_lookup"],
        "scope": "opendata",
    },
}



def _dedup_key(event: AgentEvent) -> str:
    """Build a deduplication key from event type + source_id."""
    return f"{event.event_type}:{event.source_id or ''}"


def _is_duplicate(event: AgentEvent) -> bool:
    """Check if this event was already seen within the dedup window."""
    now = time.monotonic()
    key = _dedup_key(event)

    # Clean old entries periodically (cheap: small dict).
    expired = [k for k, ts in _recent_events.items() if now - ts > _DEDUP_WINDOW_SECONDS]
    for k in expired:
        _recent_events.pop(k, None)

    if key in _recent_events and (now - _recent_events[key]) < _DEDUP_WINDOW_SECONDS:
        return True

    _recent_events[key] = now
    return False


def _build_prompt(event: AgentEvent, config: dict[str, Any]) -> str:
    """Render the prompt template with event data."""
    data = dict(event.data)
    data.setdefault("event_type", event.event_type)
    data.setdefault("camera", data.get("camera_name", "unknown"))
    data.setdefault("label", data.get("label", ""))
    data.setdefault("score", data.get("score", ""))
    data.setdefault("zone", data.get("zone", ""))
    data.setdefault("last_seen", data.get("last_seen", ""))
    data.setdefault("report_count", data.get("report_count", 0))
    data.setdefault("categories", data.get("categories", ""))
    data.setdefault("date", data.get("date", datetime.now(UTC).strftime("%Y-%m-%d")))
    data.setdefault("dataset", data.get("dataset", ""))
    data.setdefault("anomaly", data.get("anomaly", ""))
    data.setdefault("extra", json.dumps(
        {k: v for k, v in event.data.items() if k not in data},
        ensure_ascii=False,
    ))

    template = config.get("prompt_template", "Analyse event: {event_type}")
    try:
        return template.format(**data)
    except KeyError:
        return template.format_map({**data, **{k: "" for k in template.split("{") if "}" in k}})


async def handle_event(event: AgentEvent, db: Session) -> AgentEventResponse:
    """Process an incoming event through the agent runtime.

    Returns an AgentEventResponse with results or deduplication notice.
    """
    # Deduplication check.
    if event.source_id and _is_duplicate(event):
        logger.info("Deduplicated event %s:%s", event.event_type, event.source_id)
        return AgentEventResponse(accepted=True, deduplicated=True)

    # Resolve event config (default to generic analyze).
    config = _EVENT_TASK_MAP.get(event.event_type, {
        "task_type": "analyze",
        "prompt_template": "Analyse event of type {event_type}. Data: {extra}",
        "tools": [],
        "scope": "general",
    })

    prompt = _build_prompt(event, config)

    request = AgentRunRequest(
        task_type=config["task_type"],
        prompt=prompt,
        source=event.source,
        scope=config.get("scope", "general"),
        priority=event.priority,
        context=event.data,
        tools=config.get("tools", []),
        image_url=event.image_url,
    )

    try:
        response = await run_agent_task(db, request)
        return AgentEventResponse(
            accepted=True,
            thread_id=response.thread_id,
            job_id=response.job_id,
        )
    except Exception as exc:
        logger.error("Event handler failed for %s: %s", event.event_type, exc)
        return AgentEventResponse(
            accepted=False,
            error=str(exc),
        )
