"""Admin metrics endpoints for the hidden dashboard."""

from pydantic import BaseModel
from fastapi import APIRouter, Request

from ..admin_metrics import extract_client_ip, metrics_store

router = APIRouter(tags=["admin-metrics"])


class HeartbeatPayload(BaseModel):
    platform: str | None = None
    app_version: str | None = None
    screen: str | None = None


@router.post("/admin/heartbeat")
def admin_heartbeat(payload: HeartbeatPayload, request: Request):
    ip = extract_client_ip(request)
    snapshot = metrics_store.record_heartbeat(
        ip=ip,
        platform=payload.platform,
        app_version=payload.app_version,
        screen=payload.screen,
    )
    return {"ok": True, "metrics": snapshot}


@router.get("/admin/metrics")
def get_admin_metrics():
    return metrics_store.snapshot()
