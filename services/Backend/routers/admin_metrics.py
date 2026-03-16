"""Runtime telemetry and protected admin endpoints."""

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel

from ..admin_metrics import (
    extract_client_ip,
    extract_device_id,
    metrics_store,
    require_admin_session,
)

router = APIRouter(tags=["admin-metrics"])


class HeartbeatPayload(BaseModel):
    platform: str | None = None
    app_version: str | None = None
    screen: str | None = None


class AdminClaimResponse(BaseModel):
    token: str
    expires_at: str | None
    ttl_seconds: int


class AdminClaimPayload(BaseModel):
    two_factor_code: str | None = None


class AccessPolicyPayload(BaseModel):
    device_id: str
    map_access: bool | None = None
    camera_access: bool | None = None
    free_access: bool | None = None
    note: str | None = None


class CameraVisibilityPayload(BaseModel):
    camera_id: str
    hidden_by_admin: bool


class DeviceUnbindPayload(BaseModel):
    device_id: str


@router.post("/runtime/heartbeat")
def runtime_heartbeat(payload: HeartbeatPayload, request: Request):
    ip = extract_client_ip(request)
    device_id = extract_device_id(request)
    metrics_store.record_heartbeat(
        device_id=device_id,
        ip=ip,
        platform=payload.platform,
        app_version=payload.app_version,
        screen=payload.screen,
    )
    return {"ok": True}


@router.get("/runtime/access-policy")
def get_runtime_access_policy(request: Request):
    device_id = extract_device_id(request)
    return metrics_store.get_access_policy(device_id)


@router.get("/cameras")
def get_public_cameras():
    return {"cameras": metrics_store.get_public_cameras()}


@router.post("/admin/session/claim", response_model=AdminClaimResponse)
def claim_admin_session(request: Request, payload: AdminClaimPayload | None = None):
    device_id = extract_device_id(request)
    return metrics_store.claim_admin_session(
        device_id=device_id,
        two_factor_code=(payload.two_factor_code if payload else None),
        ip=extract_client_ip(request),
    )


@router.post("/admin/session/release")
def release_admin_session(request: Request, _device_id: str = Depends(require_admin_session)):
    token = request.headers.get("authorization", "").split(" ", 1)[1].strip()
    metrics_store.release_admin_session(device_id=_device_id, token=token)
    return {"ok": True}


@router.get("/admin/metrics")
def get_admin_metrics(_device_id: str = Depends(require_admin_session)):
    return metrics_store.snapshot()


@router.post("/admin/device-policy")
def update_admin_device_policy(
    payload: AccessPolicyPayload,
    _device_id: str = Depends(require_admin_session),
):
    return metrics_store.update_access_policy(
        device_id=payload.device_id,
        map_access=payload.map_access,
        camera_access=payload.camera_access,
        free_access=payload.free_access,
        note=payload.note,
    )


@router.post("/admin/device-unbind")
def unbind_admin_device(
    payload: DeviceUnbindPayload,
    _device_id: str = Depends(require_admin_session),
):
    return metrics_store.unbind_device(device_id=payload.device_id)


@router.get("/admin/cameras")
def get_admin_cameras(_device_id: str = Depends(require_admin_session)):
    return {"cameras": metrics_store.get_admin_cameras()}


@router.post("/admin/cameras/recheck")
def recheck_admin_cameras(_device_id: str = Depends(require_admin_session)):
    return metrics_store.refresh_camera_streamability()


@router.post("/admin/camera-visibility")
def update_camera_visibility(
    payload: CameraVisibilityPayload,
    _device_id: str = Depends(require_admin_session),
):
    return metrics_store.set_camera_hidden_by_admin(
        camera_id=payload.camera_id,
        hidden=payload.hidden_by_admin,
    )
