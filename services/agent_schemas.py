from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class AgentToolCall(BaseModel):
    name: str
    input_summary: str | None = None
    output_summary: str | None = None
    success: bool = False
    latency_ms: int | None = None


class AgentRunRequest(BaseModel):
    task_type: str = Field(default="analyze", pattern="^(analyze|summarize|classify|notify)$")
    prompt: str = Field(min_length=1, max_length=12000)
    source: str = Field(default="manual", max_length=80)
    scope: str = Field(default="internal", max_length=120)
    priority: str = Field(default="normal", pattern="^(low|normal|high)$")
    thread_id: int | None = None
    context: dict[str, Any] = Field(default_factory=dict)
    tools: list[str] = Field(default_factory=list)
    tool_inputs: dict[str, dict[str, Any]] = Field(default_factory=dict)
    image_url: str | None = Field(default=None, max_length=4000)
    image_base64: str | None = Field(default=None, max_length=4_000_000)


class AgentRunResult(BaseModel):
    status: str
    result: Any = None
    confidence: float = 0.0
    notes: list[str] = Field(default_factory=list)
    tool_calls: list[AgentToolCall] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)
    provider: str | None = None
    model: str | None = None


class AgentRunResponse(BaseModel):
    thread_id: int
    job_id: int
    runtime: AgentRunResult


class AgentThreadResponse(BaseModel):
    id: int
    source: str
    scope: str
    task_type: str
    title: str | None
    status: str
    metadata: dict[str, Any]
    created_at: datetime | None
    updated_at: datetime | None


class AgentMessageResponse(BaseModel):
    id: int
    thread_id: int
    role: str
    content: str | None
    structured_payload: Any = None
    model: str | None
    prompt_tokens: int | None
    completion_tokens: int | None
    total_tokens: int | None
    created_at: datetime | None


class AgentJobResponse(BaseModel):
    id: int
    thread_id: int
    job_type: str
    priority: str
    status: str
    context: Any = None
    result_summary: str | None
    error_text: str | None
    started_at: datetime | None
    finished_at: datetime | None
    created_at: datetime | None
