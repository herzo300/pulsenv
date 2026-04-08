from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from backend.database import get_db
from services.agent_memory import (
    get_thread_or_none,
    list_jobs,
    list_thread_messages,
    serialize_job,
    serialize_message,
    serialize_thread,
)
from services.agent_runtime import run_agent_task
from services.agent_schemas import (
    AgentJobResponse,
    AgentMessageResponse,
    AgentRunRequest,
    AgentRunResponse,
    AgentThreadResponse,
)
from services.Backend.security import require_admin_api_token

router = APIRouter(prefix="/agent", tags=["agent"])


def _require_admin(request: Request) -> None:
    require_admin_api_token(request)


@router.post("/run", response_model=AgentRunResponse)
async def run_agent(
    payload: AgentRunRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    _require_admin(request)
    return await run_agent_task(db, payload)


@router.get("/jobs", response_model=list[AgentJobResponse])
def get_agent_jobs(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    _require_admin(request)
    return [serialize_job(job) for job in list_jobs(db, limit=limit)]


@router.get("/threads/{thread_id}", response_model=AgentThreadResponse)
def get_agent_thread(
    thread_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    _require_admin(request)
    thread = get_thread_or_none(db, thread_id)
    if thread is None:
        raise HTTPException(status_code=404, detail="Agent thread not found")
    return serialize_thread(thread)


@router.get("/threads/{thread_id}/messages", response_model=list[AgentMessageResponse])
def get_agent_thread_messages(
    thread_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    _require_admin(request)
    thread = get_thread_or_none(db, thread_id)
    if thread is None:
        raise HTTPException(status_code=404, detail="Agent thread not found")
    return [serialize_message(message) for message in list_thread_messages(db, thread_id)]
