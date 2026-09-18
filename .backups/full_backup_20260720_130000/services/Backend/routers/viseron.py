"""Viseron NVR webhook and status endpoints."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

from services.monitoring.viseron_bridge import (
    get_viseron_status,
    handle_viseron_webhook,
    verify_webhook_token,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/nvr/viseron", tags=["viseron"])


class ViseronWebhookPayload(BaseModel):
    camera: str | None = None
    camera_identifier: str | None = None
    camera_id: str | None = None
    label: str | None = None
    object: str | None = None
    event: str | None = None
    event_type: str | None = None
    count: int | None = Field(default=None, ge=1)
    confidence: float | None = Field(default=None, ge=0, le=1)
    description: str | None = None
    snapshot_base64: str | None = None

    model_config = {"extra": "allow"}


@router.get("/status")
async def viseron_status() -> dict[str, Any]:
    return get_viseron_status()


@router.post("/webhook")
async def viseron_webhook(
    request: Request,
    x_viseron_token: str | None = Header(default=None, alias="X-Viseron-Token"),
) -> dict[str, Any]:
    if not verify_webhook_token(x_viseron_token):
        raise HTTPException(status_code=401, detail="Invalid Viseron webhook token")

    try:
        body = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid JSON body") from exc

    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="JSON object expected")

    bot = getattr(request.app.state, "telegram_monitor", None)
    bot_client = getattr(bot, "client", None) if bot else None
    return await handle_viseron_webhook(body, bot=bot_client)
