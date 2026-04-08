"""Runtime telemetry and protected admin endpoints."""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy import func, or_

from backend.database import SessionLocal
from backend.models import GeoSubscription, Report
from services.cache_service import get_categories_cached

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


class WatchdogScanPayload(BaseModel):
    max_cameras: int = 5


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _public_source_filter():
    return or_(
        Report.source.like("vk:%"),
        Report.source.like("tg:%"),
        Report.source.like("telegram:%"),
    )


def _report_excerpt(report: Report | None) -> dict[str, Any] | None:
    if report is None:
        return None
    return {
        "id": report.id,
        "title": report.title,
        "category": report.category,
        "address": report.address,
        "lat": float(report.lat) if report.lat is not None else None,
        "lng": float(report.lng) if report.lng is not None else None,
        "source": report.source,
        "created_at": report.created_at.isoformat() if report.created_at else None,
    }


def _derive_attack_signal(snapshot: dict[str, Any]) -> dict[str, Any]:
    requests_last_hour = int(snapshot.get("requests_last_hour") or 0)
    active_users = int(snapshot.get("active_unique_users") or 0)
    top_routes = snapshot.get("top_routes") or []

    admin_claim_hits = 0
    for row in top_routes:
        if not isinstance(row, dict):
            continue
        path = str(row.get("path") or "")
        if path.endswith("/api/admin/session/claim"):
            admin_claim_hits = max(admin_claim_hits, int(row.get("hits") or 0))

    level = "low"
    label = "Низкий шум"
    if requests_last_hour >= 3000 or admin_claim_hits >= 40:
        level = "high"
        label = "Высокий шум / вероятна атака"
    elif requests_last_hour >= 1200 or active_users >= 80 or admin_claim_hits >= 15:
        level = "elevated"
        label = "Повышенный шум / нужна проверка"

    return {
        "level": level,
        "label": label,
        "requests_last_hour": requests_last_hour,
        "active_users": active_users,
        "admin_claim_hits": admin_claim_hits,
        "top_routes": top_routes[:5] if isinstance(top_routes, list) else [],
    }


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


@router.get("/admin/notification-diagnostics")
def get_admin_notification_diagnostics(_device_id: str = Depends(require_admin_session)):
    snapshot = metrics_store.snapshot()
    now = _utcnow()
    hour_threshold = now - timedelta(hours=1)
    day_threshold = now - timedelta(hours=24)
    public_filter = _public_source_filter()

    db = SessionLocal()
    try:
        latest_report = db.query(Report).order_by(Report.created_at.desc()).first()
        latest_public_report = (
            db.query(Report)
            .filter(public_filter)
            .order_by(Report.created_at.desc())
            .first()
        )
        latest_geocoded_public_report = (
            db.query(Report)
            .filter(
                public_filter,
                Report.lat.isnot(None),
                Report.lng.isnot(None),
            )
            .order_by(Report.created_at.desc())
            .first()
        )
        latest_notifiable_report = (
            db.query(Report)
            .filter(Report.lat.isnot(None), Report.lng.isnot(None))
            .order_by(Report.created_at.desc())
            .first()
        )

        public_reports_last_hour = (
            db.query(func.count(Report.id))
            .filter(public_filter, Report.created_at >= hour_threshold)
            .scalar()
            or 0
        )
        public_reports_last_day = (
            db.query(func.count(Report.id))
            .filter(public_filter, Report.created_at >= day_threshold)
            .scalar()
            or 0
        )
        public_reports_with_coords_last_day = (
            db.query(func.count(Report.id))
            .filter(
                public_filter,
                Report.created_at >= day_threshold,
                Report.lat.isnot(None),
                Report.lng.isnot(None),
            )
            .scalar()
            or 0
        )
        public_reports_without_coords_last_day = max(
            0,
            int(public_reports_last_day) - int(public_reports_with_coords_last_day),
        )

        recent_unlocated_public = (
            db.query(Report)
            .filter(
                public_filter,
                Report.created_at >= day_threshold,
                or_(Report.lat.is_(None), Report.lng.is_(None)),
            )
            .order_by(Report.created_at.desc())
            .limit(5)
            .all()
        )

        geo_subscriptions_total = (
            db.query(func.count(GeoSubscription.id)).scalar()
            or 0
        )
        geo_subscriptions_active = (
            db.query(func.count(GeoSubscription.id))
            .filter(GeoSubscription.is_active.is_(True))
            .scalar()
            or 0
        )
        filtered_geo_subscriptions = (
            db.query(func.count(GeoSubscription.id))
            .filter(
                GeoSubscription.is_active.is_(True),
                GeoSubscription.categories.isnot(None),
                GeoSubscription.categories != "",
            )
            .scalar()
            or 0
        )
        unique_geo_subscribers = (
            db.query(func.count(func.distinct(GeoSubscription.telegram_id)))
            .filter(GeoSubscription.is_active.is_(True))
            .scalar()
            or 0
        )

        categories = get_categories_cached()
        categories_preview = [
            str(item.get("name") or "").strip()
            for item in categories[:8]
            if isinstance(item, dict) and str(item.get("name") or "").strip()
        ]

        tg_token_configured = bool(
            (os.getenv("TG_BOT_TOKEN") or os.getenv("TELEGRAM_BOT_TOKEN") or "").strip()
        )
        coords_coverage = (
            float(public_reports_with_coords_last_day) / float(public_reports_last_day)
            if public_reports_last_day
            else 1.0
        )
        status = "ready"
        if not tg_token_configured or not categories:
            status = "degraded"
        elif public_reports_last_day and coords_coverage < 0.35:
            status = "degraded"

        return {
            "status": status,
            "generated_at": now.isoformat(),
            "backend": {
                "storage_mode": snapshot.get("storage_mode"),
                "uptime_human": snapshot.get("uptime_human"),
                "requests_last_hour": int(snapshot.get("requests_last_hour") or 0),
                "requests_last_24_hours": int(snapshot.get("requests_last_24_hours") or 0),
                "active_unique_users": int(snapshot.get("active_unique_users") or 0),
            },
            "notifications": {
                "telegram_push_configured": tg_token_configured,
                "geo_subscriptions_total": int(geo_subscriptions_total),
                "geo_subscriptions_active": int(geo_subscriptions_active),
                "filtered_geo_subscriptions": int(filtered_geo_subscriptions),
                "unique_geo_subscribers": int(unique_geo_subscribers),
                "categories_count": len(categories),
                "categories_preview": categories_preview,
                "latest_notifiable_report": _report_excerpt(latest_notifiable_report),
                "latest_report": _report_excerpt(latest_report),
            },
            "ingestion": {
                "public_reports_last_hour": int(public_reports_last_hour),
                "public_reports_last_24_hours": int(public_reports_last_day),
                "public_reports_with_coords_last_24_hours": int(public_reports_with_coords_last_day),
                "public_reports_without_coords_last_24_hours": int(public_reports_without_coords_last_day),
                "coords_coverage_ratio": round(coords_coverage, 3),
                "latest_public_report": _report_excerpt(latest_public_report),
                "latest_geocoded_public_report": _report_excerpt(latest_geocoded_public_report),
                "recent_unlocated_public": [_report_excerpt(item) for item in recent_unlocated_public],
            },
            "security": _derive_attack_signal(snapshot),
        }
    finally:
        db.close()


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


@router.get("/admin/cameras/secret")
def get_admin_secret_cameras(_device_id: str = Depends(require_admin_session)):
    return {"cameras": metrics_store.get_secret_cameras()}


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


@router.get("/admin/watchdog/status")
async def get_admin_watchdog_status(_device_id: str = Depends(require_admin_session)):
    from .watchdog import collect_watchdog_status

    return await collect_watchdog_status()


@router.get("/admin/watchdog/alerts")
def get_admin_watchdog_alerts(
    limit: int = 20,
    _device_id: str = Depends(require_admin_session),
):
    from .watchdog import collect_watchdog_alerts

    return collect_watchdog_alerts(limit=limit)


@router.post("/admin/watchdog/scan")
async def run_admin_watchdog_scan(
    payload: WatchdogScanPayload | None = None,
    _device_id: str = Depends(require_admin_session),
):
    from .watchdog import run_watchdog_scan

    requested = int(payload.max_cameras) if payload is not None else 5
    max_cameras = max(1, min(requested, 25))
    return await run_watchdog_scan(max_cameras=max_cameras)
