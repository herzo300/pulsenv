"""Utility helpers for admin metrics: time, hashing, extraction, camera helpers."""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, Request, status

# Time window constants
ACTIVE_WINDOW_SECONDS = 150
LAST_HOUR_SECONDS = 3600
LAST_DAY_SECONDS = 86400
LAST_WEEK_SECONDS = 7 * LAST_DAY_SECONDS


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _now_ts() -> float:
    return _utcnow().timestamp()


def _isoformat(value: datetime | None) -> str | None:
    if value is None:
        return None
    return _as_utc(value).isoformat()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _humanize_seconds(seconds: int) -> str:
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)
    parts: list[str] = []
    if days:
        parts.append(f"{days}d")
    if hours or parts:
        parts.append(f"{hours}h")
    if minutes or parts:
        parts.append(f"{minutes}m")
    parts.append(f"{secs}s")
    return " ".join(parts)


def _hash_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _safe_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _camera_fingerprint(*, name: str, lat: float, lng: float, stream_url: str) -> str:
    stable = f"{name.strip()}|{lat:.6f}|{lng:.6f}|{stream_url.strip()}"
    return _hash_text(stable)


def _normalize_camera_stream_url(stream_url: str) -> str:
    normalized = (stream_url or "").strip()
    if not normalized:
        return ""
    lower = normalized.lower()
    if "pride-net.ru" in lower and ".m3u8" not in lower:
        return normalized.rstrip("/") + "/index.m3u8"
    return normalized


def extract_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()

    real_ip = request.headers.get("x-real-ip", "").strip()
    if real_ip:
        return real_ip

    return (request.client.host if request.client else "unknown").strip() or "unknown"


def extract_device_id(request: Request) -> str:
    raw = (
        request.headers.get("x-client-device-id")
        or request.headers.get("x-device-id")
        or ""
    ).strip()
    if not raw:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Client-Device-Id header is required",
        )
    if len(raw) > 128:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Device id is too long",
        )
    return raw
