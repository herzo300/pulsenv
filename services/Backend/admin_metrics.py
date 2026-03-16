"""Supabase/Postgres-backed runtime metrics and admin session management."""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import threading
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import httpx
from fastapi import HTTPException, Request, status
from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Float,
    Integer,
    String,
    Text,
    create_engine,
    desc,
    func,
    select,
)
from sqlalchemy.orm import Session, sessionmaker

from backend.database import Base, SessionLocal, engine

ACTIVE_WINDOW_SECONDS = 150
LAST_HOUR_SECONDS = 3600
LAST_DAY_SECONDS = 86400
LAST_WEEK_SECONDS = 7 * LAST_DAY_SECONDS
ADMIN_SESSION_TTL_SECONDS = 900
ADMIN_SESSION_ROW_ID = "global"
ADMIN_CLAIM_RATE_LIMIT_WINDOW_SECONDS = 5 * 60
ADMIN_CLAIM_RATE_LIMIT_ATTEMPTS = 8
DEFAULT_ACCESS_POLICY = {
    "map_access": True,
    "camera_access": True,
    "free_access": True,
    "note": "",
}
ROOT = Path(__file__).resolve().parent.parent.parent
FALLBACK_SQLITE_PATH = ROOT / "data" / "admin_runtime_fallback.db"
CAMERA_SOURCE_FILES = (
    ROOT / "services" / "Frontend" / "assets" / "cameras_nv.json",
    ROOT / "public" / "cameras_nv.json",
)
CAMERA_PROBE_TIMEOUT_SECONDS = 6.0
CAMERA_PROBE_USER_AGENT = "SoobshioCameraProbe/1.0"
ADMIN_2FA_PASSWORD = (
    os.getenv("ADMIN_2FA_PASSWORD", "").strip()
    or os.getenv("TG_2FA_PASSWORD", "").strip()
)
ADMIN_REQUIRE_2FA = (
    (os.getenv("ADMIN_REQUIRE_2FA") or "").strip().lower() in {"1", "true", "yes", "on"}
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _now_ts() -> float:
    return _utcnow().timestamp()


def _isoformat(value: datetime | None) -> str | None:
    if value is None:
        return None
    return _as_utc(value).isoformat()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


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


class AdminRuntimeStats(Base):
    __tablename__ = "admin_runtime_stats"

    id = Column(String(32), primary_key=True, default=ADMIN_SESSION_ROW_ID)
    started_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_activity_at = Column(DateTime(timezone=True), nullable=True)
    total_requests = Column(BigInteger, nullable=False, default=0)
    total_heartbeats = Column(BigInteger, nullable=False, default=0)
    total_request_bytes = Column(BigInteger, nullable=False, default=0)
    total_response_bytes = Column(BigInteger, nullable=False, default=0)
    peak_active_devices = Column(Integer, nullable=False, default=0)


class AdminRuntimeDevice(Base):
    __tablename__ = "admin_runtime_devices"

    device_id = Column(String(128), primary_key=True)
    platform = Column(String(32), nullable=False, default="unknown")
    app_version = Column(String(32), nullable=False, default="unknown")
    current_screen = Column(String(64), nullable=False, default="unknown")
    first_seen_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_seen_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_ip = Column(String(64), nullable=False, default="unknown")
    heartbeat_count = Column(BigInteger, nullable=False, default=0)
    request_count = Column(BigInteger, nullable=False, default=0)
    total_request_bytes = Column(BigInteger, nullable=False, default=0)
    total_response_bytes = Column(BigInteger, nullable=False, default=0)


class AdminRequestEvent(Base):
    __tablename__ = "admin_request_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(128), nullable=False, index=True)
    route = Column(String(255), nullable=False, index=True)
    happened_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow, index=True)
    request_bytes = Column(BigInteger, nullable=False, default=0)
    response_bytes = Column(BigInteger, nullable=False, default=0)


class AdminHeartbeatEvent(Base):
    __tablename__ = "admin_heartbeat_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(128), nullable=False, index=True)
    platform = Column(String(32), nullable=False, default="unknown")
    app_version = Column(String(32), nullable=False, default="unknown")
    screen = Column(String(64), nullable=False, default="unknown")
    ip = Column(String(64), nullable=False, default="unknown")
    happened_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow, index=True)


class AdminAccessPolicy(Base):
    __tablename__ = "admin_access_policies"

    device_id = Column(String(128), primary_key=True)
    map_access = Column(Boolean, nullable=False, default=True)
    camera_access = Column(Boolean, nullable=False, default=True)
    free_access = Column(Boolean, nullable=False, default=True)
    note = Column(Text, nullable=False, default="")
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)


class AdminSessionLock(Base):
    __tablename__ = "admin_session_locks"

    id = Column(String(32), primary_key=True, default=ADMIN_SESSION_ROW_ID)
    device_id_hash = Column(String(64), nullable=True)
    session_token_hash = Column(String(64), nullable=True)
    session_expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    last_seen_at = Column(DateTime(timezone=True), nullable=True)


class AdminCameraCatalog(Base):
    __tablename__ = "admin_camera_catalog"

    camera_id = Column(String(64), primary_key=True)
    name = Column(String(255), nullable=False, default="Камера")
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    stream_url = Column(Text, nullable=False)
    streamable = Column(Boolean, nullable=False, default=True)
    hidden_by_admin = Column(Boolean, nullable=False, default=False)
    hidden_due_to_offline = Column(Boolean, nullable=False, default=False)
    probe_http_status = Column(Integer, nullable=True)
    probe_error = Column(Text, nullable=False, default="")
    last_checked_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow)


class AdminRuntimeStore:
    """DB-backed runtime metrics store suitable for Supabase Postgres."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._engine = engine
        self._session_factory = SessionLocal
        self._initialized = False
        self._storage_mode = "supabase_postgres"
        self._admin_claim_attempts: dict[str, list[float]] = {}

    def _db(self) -> Session:
        self._ensure_ready()
        return self._session_factory()

    def _initialize_schema(self) -> None:
        Base.metadata.create_all(
            bind=self._engine,
            tables=[
                AdminRuntimeStats.__table__,
                AdminRuntimeDevice.__table__,
                AdminRequestEvent.__table__,
                AdminHeartbeatEvent.__table__,
                AdminAccessPolicy.__table__,
                AdminSessionLock.__table__,
                AdminCameraCatalog.__table__,
            ],
        )

    def _ensure_stats_row(self) -> None:
        db = self._session_factory()
        try:
            stats = db.get(AdminRuntimeStats, ADMIN_SESSION_ROW_ID)
            if stats is None:
                db.add(AdminRuntimeStats(id=ADMIN_SESSION_ROW_ID))
                db.commit()
        finally:
            db.close()

    def _load_camera_source_rows(self) -> list[dict[str, Any]]:
        source_path = next((path for path in CAMERA_SOURCE_FILES if path.exists()), None)
        if source_path is None:
            return []

        try:
            payload = json.loads(source_path.read_text(encoding="utf-8"))
        except Exception:
            return []

        if not isinstance(payload, list):
            return []

        cameras: list[dict[str, Any]] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            lat = _safe_float(item.get("lat") if item.get("lat") is not None else item.get("latitude"))
            lng = _safe_float(item.get("lng") if item.get("lng") is not None else item.get("lon"))
            stream_url = (item.get("s") or item.get("url") or "").strip()
            if lat is None or lng is None or not stream_url:
                continue
            name = str(item.get("n") or item.get("name") or "Камера").strip() or "Камера"
            camera_id = _camera_fingerprint(name=name, lat=lat, lng=lng, stream_url=stream_url)
            cameras.append(
                {
                    "camera_id": camera_id,
                    "name": name[:255],
                    "lat": lat,
                    "lng": lng,
                    "stream_url": stream_url[:2000],
                }
            )
        return cameras

    def _sync_camera_catalog_locked(self, db: Session) -> int:
        source_cameras = self._load_camera_source_rows()
        if not source_cameras:
            return 0

        existing = {
            row.camera_id: row
            for row in db.query(AdminCameraCatalog).all()
        }
        now = _utcnow()

        for cam in source_cameras:
            row = existing.get(cam["camera_id"])
            if row is None:
                row = AdminCameraCatalog(
                    camera_id=cam["camera_id"],
                    streamable=True,
                    hidden_by_admin=False,
                    hidden_due_to_offline=False,
                )
                db.add(row)
            row.name = cam["name"]
            row.lat = cam["lat"]
            row.lng = cam["lng"]
            row.stream_url = cam["stream_url"]
            row.updated_at = now
        return len(source_cameras)

    def sync_camera_catalog(self) -> int:
        with self._lock:
            db = self._db()
            try:
                count = self._sync_camera_catalog_locked(db)
                db.commit()
                return count
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def _activate_fallback_sqlite(self) -> None:
        FALLBACK_SQLITE_PATH.parent.mkdir(parents=True, exist_ok=True)
        self._engine = create_engine(
            f"sqlite:///{FALLBACK_SQLITE_PATH.as_posix()}",
            connect_args={"check_same_thread": False, "timeout": 30},
        )
        self._session_factory = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=self._engine,
        )
        self._storage_mode = "local_fallback_sqlite"

    def _ensure_ready(self) -> None:
        if self._initialized:
            return

        with self._lock:
            if self._initialized:
                return

            try:
                self._initialize_schema()
                self._ensure_stats_row()
                bootstrap_db = self._session_factory()
                try:
                    self._sync_camera_catalog_locked(bootstrap_db)
                    bootstrap_db.commit()
                finally:
                    bootstrap_db.close()
                self._initialized = True
                return
            except Exception:
                self._activate_fallback_sqlite()
                self._initialize_schema()
                self._ensure_stats_row()
                bootstrap_db = self._session_factory()
                try:
                    self._sync_camera_catalog_locked(bootstrap_db)
                    bootstrap_db.commit()
                finally:
                    bootstrap_db.close()
                self._initialized = True

    def _get_or_create_stats(self, db: Session) -> AdminRuntimeStats:
        stats = db.get(AdminRuntimeStats, ADMIN_SESSION_ROW_ID)
        if stats is None:
            stats = AdminRuntimeStats(id=ADMIN_SESSION_ROW_ID)
            db.add(stats)
            db.flush()
        return stats

    def _get_or_create_device(self, db: Session, device_id: str) -> AdminRuntimeDevice:
        device = db.get(AdminRuntimeDevice, device_id)
        if device is None:
            device = AdminRuntimeDevice(device_id=device_id)
            db.add(device)
            db.flush()
        return device

    def _get_or_create_policy(self, db: Session, device_id: str) -> AdminAccessPolicy:
        policy = db.get(AdminAccessPolicy, device_id)
        if policy is None:
            policy = AdminAccessPolicy(device_id=device_id, **DEFAULT_ACCESS_POLICY)
            db.add(policy)
            db.flush()
        return policy

    def _update_peak_active_devices(self, db: Session, stats: AdminRuntimeStats) -> None:
        threshold = _utcnow() - timedelta(seconds=ACTIVE_WINDOW_SECONDS)
        active_now = (
            db.query(func.count(AdminRuntimeDevice.device_id))
            .filter(AdminRuntimeDevice.last_seen_at >= threshold)
            .scalar()
            or 0
        )
        if active_now > (stats.peak_active_devices or 0):
            stats.peak_active_devices = int(active_now)

    def record_request(
        self,
        *,
        device_id: str,
        ip: str,
        path: str,
        request_bytes: int = 0,
        response_bytes: int = 0,
    ) -> None:
        request_bytes = max(0, int(request_bytes))
        response_bytes = max(0, int(response_bytes))
        now = _utcnow()
        with self._lock:
            db = self._db()
            try:
                stats = self._get_or_create_stats(db)
                device = self._get_or_create_device(db, device_id)
                self._get_or_create_policy(db, device_id)

                device.last_seen_at = now
                device.last_ip = ip or "unknown"
                device.request_count = int(device.request_count or 0) + 1
                device.total_request_bytes = int(device.total_request_bytes or 0) + request_bytes
                device.total_response_bytes = int(device.total_response_bytes or 0) + response_bytes

                db.add(
                    AdminRequestEvent(
                        device_id=device_id,
                        route=path[:255],
                        happened_at=now,
                        request_bytes=request_bytes,
                        response_bytes=response_bytes,
                    )
                )

                stats.total_requests = int(stats.total_requests or 0) + 1
                stats.total_request_bytes = int(stats.total_request_bytes or 0) + request_bytes
                stats.total_response_bytes = int(stats.total_response_bytes or 0) + response_bytes
                stats.last_activity_at = now
                self._update_peak_active_devices(db, stats)
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def record_heartbeat(
        self,
        *,
        device_id: str,
        ip: str,
        platform: str | None,
        app_version: str | None,
        screen: str | None,
    ) -> None:
        now = _utcnow()
        with self._lock:
            db = self._db()
            try:
                stats = self._get_or_create_stats(db)
                device = self._get_or_create_device(db, device_id)
                self._get_or_create_policy(db, device_id)

                device.platform = (platform or device.platform or "unknown").strip() or "unknown"
                device.app_version = (
                    app_version or device.app_version or "unknown"
                ).strip() or "unknown"
                device.current_screen = (screen or device.current_screen or "unknown").strip() or "unknown"
                device.last_ip = ip or device.last_ip or "unknown"
                device.last_seen_at = now
                device.heartbeat_count = int(device.heartbeat_count or 0) + 1

                db.add(
                    AdminHeartbeatEvent(
                        device_id=device_id,
                        platform=device.platform,
                        app_version=device.app_version,
                        screen=device.current_screen,
                        ip=device.last_ip,
                        happened_at=now,
                    )
                )

                stats.total_heartbeats = int(stats.total_heartbeats or 0) + 1
                stats.last_activity_at = now
                self._update_peak_active_devices(db, stats)
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def get_access_policy(self, device_id: str) -> dict[str, Any]:
        db = self._db()
        try:
            policy = self._get_or_create_policy(db, device_id)
            db.commit()
            return self._policy_to_dict(policy)
        finally:
            db.close()

    def update_access_policy(
        self,
        *,
        device_id: str,
        map_access: bool | None,
        camera_access: bool | None,
        free_access: bool | None,
        note: str | None,
    ) -> dict[str, Any]:
        db = self._db()
        try:
            policy = self._get_or_create_policy(db, device_id)
            if map_access is not None:
                policy.map_access = bool(map_access)
            if camera_access is not None:
                policy.camera_access = bool(camera_access)
            if free_access is not None:
                policy.free_access = bool(free_access)
            if note is not None:
                policy.note = note.strip()[:500]
            policy.updated_at = _utcnow()
            db.commit()
            db.refresh(policy)
            return self._policy_to_dict(policy)
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def _ensure_admin_2fa(self, two_factor_code: str | None) -> None:
        if not ADMIN_REQUIRE_2FA:
            return

        if not ADMIN_2FA_PASSWORD:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="ADMIN_2FA_PASSWORD is not configured",
            )

        candidate = (two_factor_code or "").strip()
        if not candidate:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="2FA code is required",
            )
        if not secrets.compare_digest(candidate, ADMIN_2FA_PASSWORD):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid 2FA code",
            )

    def _trim_claim_attempts(self, key: str, now_ts: float) -> list[float]:
        attempts = self._admin_claim_attempts.get(key, [])
        if not attempts:
            return []
        threshold = now_ts - ADMIN_CLAIM_RATE_LIMIT_WINDOW_SECONDS
        attempts = [ts for ts in attempts if ts >= threshold]
        self._admin_claim_attempts[key] = attempts
        return attempts

    def _assert_claim_rate_limit(self, keys: list[str]) -> None:
        now_ts = _now_ts()
        for key in keys:
            attempts = self._trim_claim_attempts(key, now_ts)
            if len(attempts) >= ADMIN_CLAIM_RATE_LIMIT_ATTEMPTS:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many invalid admin login attempts, try again later",
                )

    def _register_claim_failure(self, keys: list[str]) -> None:
        now_ts = _now_ts()
        for key in keys:
            attempts = self._trim_claim_attempts(key, now_ts)
            attempts.append(now_ts)
            self._admin_claim_attempts[key] = attempts

    def _clear_claim_attempts(self, keys: list[str]) -> None:
        for key in keys:
            self._admin_claim_attempts.pop(key, None)

    def _camera_to_dict(self, camera: AdminCameraCatalog) -> dict[str, Any]:
        hidden_in_map = bool(
            camera.hidden_by_admin or camera.hidden_due_to_offline or not camera.streamable
        )
        return {
            "camera_id": camera.camera_id,
            "name": camera.name,
            "n": camera.name,
            "lat": float(camera.lat),
            "lng": float(camera.lng),
            "stream_url": camera.stream_url,
            "s": camera.stream_url,
            "streamable": bool(camera.streamable),
            "hidden_in_map": hidden_in_map,
            "hidden_by_admin": bool(camera.hidden_by_admin),
            "hidden_due_to_offline": bool(camera.hidden_due_to_offline),
            "probe_http_status": camera.probe_http_status,
            "probe_error": (camera.probe_error or "")[:500],
            "last_checked_at": _isoformat(camera.last_checked_at),
            "updated_at": _isoformat(camera.updated_at),
        }

    def get_public_cameras(self) -> list[dict[str, Any]]:
        self.sync_camera_catalog()
        db = self._db()
        try:
            rows = (
                db.query(AdminCameraCatalog)
                .filter(AdminCameraCatalog.streamable.is_(True))
                .filter(AdminCameraCatalog.hidden_by_admin.is_(False))
                .filter(AdminCameraCatalog.hidden_due_to_offline.is_(False))
                .order_by(AdminCameraCatalog.name.asc())
                .all()
            )
            return [self._camera_to_dict(row) for row in rows]
        finally:
            db.close()

    def get_admin_cameras(self) -> list[dict[str, Any]]:
        self.sync_camera_catalog()
        db = self._db()
        try:
            rows = db.query(AdminCameraCatalog).order_by(AdminCameraCatalog.name.asc()).all()
            return [self._camera_to_dict(row) for row in rows]
        finally:
            db.close()

    def refresh_camera_streamability(
        self,
        *,
        timeout_seconds: float = CAMERA_PROBE_TIMEOUT_SECONDS,
    ) -> dict[str, Any]:
        self.sync_camera_catalog()

        db = self._db()
        try:
            snapshots = [
                (row.camera_id, row.stream_url)
                for row in db.query(AdminCameraCatalog).all()
            ]
        finally:
            db.close()

        checks: list[tuple[str, bool, int | None, str]] = []
        headers = {"User-Agent": CAMERA_PROBE_USER_AGENT}
        with httpx.Client(follow_redirects=True, timeout=timeout_seconds, headers=headers) as client:
            for camera_id, url in snapshots:
                try:
                    response = client.get(url)
                    body_prefix = response.text[:2048].upper() if response.status_code == 200 else ""
                    looks_hls = "#EXTM3U" in body_prefix or ".M3U8" in url.upper()
                    is_streamable = response.status_code == 200 and looks_hls
                    checks.append((camera_id, is_streamable, response.status_code, ""))
                except Exception as error:
                    checks.append((camera_id, False, None, str(error)[:500]))

        with self._lock:
            db = self._db()
            try:
                now = _utcnow()
                online_count = 0
                hidden_count = 0
                for camera_id, is_streamable, http_status, error_text in checks:
                    row = db.get(AdminCameraCatalog, camera_id)
                    if row is None:
                        continue
                    row.streamable = bool(is_streamable)
                    row.hidden_due_to_offline = not bool(is_streamable)
                    row.probe_http_status = http_status
                    row.probe_error = error_text
                    row.last_checked_at = now
                    row.updated_at = now
                    if row.streamable:
                        online_count += 1
                    if row.hidden_by_admin or row.hidden_due_to_offline:
                        hidden_count += 1
                db.commit()
                return {
                    "total": len(checks),
                    "streamable": online_count,
                    "hidden": hidden_count,
                    "checked_at": _isoformat(now),
                }
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def set_camera_hidden_by_admin(self, *, camera_id: str, hidden: bool) -> dict[str, Any]:
        with self._lock:
            db = self._db()
            try:
                row = db.get(AdminCameraCatalog, camera_id)
                if row is None:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Camera not found",
                    )
                row.hidden_by_admin = bool(hidden)
                row.updated_at = _utcnow()
                db.commit()
                db.refresh(row)
                return self._camera_to_dict(row)
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def unbind_device(self, *, device_id: str) -> dict[str, Any]:
        device_id = device_id.strip()
        if not device_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="device_id is required",
            )

        with self._lock:
            db = self._db()
            try:
                device = db.get(AdminRuntimeDevice, device_id)
                policy = db.get(AdminAccessPolicy, device_id)
                if policy is not None:
                    db.delete(policy)
                if device is not None:
                    db.delete(device)

                released_session = False
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row and session_row.device_id_hash == _hash_text(device_id):
                    session_row.session_token_hash = None
                    session_row.session_expires_at = None
                    session_row.last_seen_at = _utcnow()
                    session_row.updated_at = _utcnow()
                    released_session = True

                db.commit()
                return {
                    "device_id": device_id,
                    "removed": bool(device is not None or policy is not None),
                    "released_admin_session": released_session,
                }
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def claim_admin_session(
        self,
        *,
        device_id: str,
        two_factor_code: str | None,
        ip: str | None = None,
    ) -> dict[str, Any]:
        limiter_keys = [f"dev:{_hash_text(device_id)}"]
        if ip:
            limiter_keys.append(f"ip:{_hash_text(ip)}")

        with self._lock:
            self._assert_claim_rate_limit(limiter_keys)
            try:
                self._ensure_admin_2fa(two_factor_code)
            except HTTPException:
                self._register_claim_failure(limiter_keys)
                raise
            self._clear_claim_attempts(limiter_keys)

        token = secrets.token_urlsafe(32)
        device_hash = _hash_text(device_id)
        token_hash = _hash_text(token)
        now = _utcnow()
        expires_at = now + timedelta(seconds=ADMIN_SESSION_TTL_SECONDS)

        with self._lock:
            db = self._db()
            try:
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row is None:
                    session_row = AdminSessionLock(id=ADMIN_SESSION_ROW_ID)
                    db.add(session_row)
                    db.flush()

                active_session = (
                    session_row.session_token_hash
                    and session_row.session_expires_at
                    and _as_utc(session_row.session_expires_at) > now
                )
                same_device = session_row.device_id_hash == device_hash
                if active_session and not same_device:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Admin session is already locked to another device",
                    )

                session_row.device_id_hash = device_hash
                session_row.session_token_hash = token_hash
                session_row.session_expires_at = expires_at
                session_row.last_seen_at = now
                session_row.updated_at = now
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

        return {
            "token": token,
            "expires_at": _isoformat(expires_at),
            "ttl_seconds": ADMIN_SESSION_TTL_SECONDS,
        }

    def release_admin_session(self, *, device_id: str, token: str) -> None:
        with self._lock:
            db = self._db()
            try:
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row is None:
                    return
                if not self._is_valid_session_row(session_row, device_id=device_id, token=token):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Admin session is not owned by this device",
                    )
                session_row.session_token_hash = None
                session_row.session_expires_at = None
                session_row.last_seen_at = _utcnow()
                session_row.updated_at = _utcnow()
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def validate_admin_session(self, *, device_id: str, token: str) -> None:
        with self._lock:
            db = self._db()
            try:
                session_row = db.get(AdminSessionLock, ADMIN_SESSION_ROW_ID)
                if session_row is None or not self._is_valid_session_row(
                    session_row,
                    device_id=device_id,
                    token=token,
                ):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Admin session is invalid or expired",
                    )
                session_row.session_expires_at = _utcnow() + timedelta(
                    seconds=ADMIN_SESSION_TTL_SECONDS
                )
                session_row.last_seen_at = _utcnow()
                session_row.updated_at = _utcnow()
                db.commit()
            except Exception:
                db.rollback()
                raise
            finally:
                db.close()

    def _is_valid_session_row(
        self,
        session_row: AdminSessionLock,
        *,
        device_id: str,
        token: str,
    ) -> bool:
        now = _utcnow()
        if not session_row.session_token_hash or not session_row.session_expires_at:
            return False
        if _as_utc(session_row.session_expires_at) <= now:
            return False
        return (
            session_row.device_id_hash == _hash_text(device_id)
            and session_row.session_token_hash == _hash_text(token)
        )

    def snapshot(self) -> dict[str, Any]:
        now = _utcnow()
        active_threshold = now - timedelta(seconds=ACTIVE_WINDOW_SECONDS)
        week_threshold = now - timedelta(seconds=LAST_WEEK_SECONDS)
        day_threshold = now - timedelta(seconds=LAST_DAY_SECONDS)
        hour_threshold = now - timedelta(seconds=LAST_HOUR_SECONDS)

        db = self._db()
        try:
            stats = self._get_or_create_stats(db)
            active_devices = (
                db.query(AdminRuntimeDevice)
                .filter(AdminRuntimeDevice.last_seen_at >= active_threshold)
                .order_by(desc(AdminRuntimeDevice.last_seen_at))
                .all()
            )
            devices = db.query(AdminRuntimeDevice).order_by(desc(AdminRuntimeDevice.last_seen_at)).limit(50).all()
            policies = {
                row.device_id: row
                for row in db.query(AdminAccessPolicy).filter(
                    AdminAccessPolicy.device_id.in_([device.device_id for device in devices] or [""])
                )
            }
            cameras_total = db.query(func.count(AdminCameraCatalog.camera_id)).scalar() or 0
            cameras_streamable = (
                db.query(func.count(AdminCameraCatalog.camera_id))
                .filter(AdminCameraCatalog.streamable.is_(True))
                .filter(AdminCameraCatalog.hidden_by_admin.is_(False))
                .filter(AdminCameraCatalog.hidden_due_to_offline.is_(False))
                .scalar()
                or 0
            )
            cameras_hidden = (
                db.query(func.count(AdminCameraCatalog.camera_id))
                .filter(
                    (AdminCameraCatalog.hidden_by_admin.is_(True))
                    | (AdminCameraCatalog.hidden_due_to_offline.is_(True))
                )
                .scalar()
                or 0
            )
            cameras_offline = (
                db.query(func.count(AdminCameraCatalog.camera_id))
                .filter(AdminCameraCatalog.streamable.is_(False))
                .scalar()
                or 0
            )

            total_unique_users = db.query(func.count(AdminRuntimeDevice.device_id)).scalar() or 0
            requests_last_hour = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(AdminRequestEvent.happened_at >= hour_threshold)
                .scalar()
                or 0
            )
            requests_last_day = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(AdminRequestEvent.happened_at >= day_threshold)
                .scalar()
                or 0
            )
            requests_last_week = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(AdminRequestEvent.happened_at >= week_threshold)
                .scalar()
                or 0
            )
            app_launches_total = (
                db.query(func.count(AdminHeartbeatEvent.id))
                .filter(AdminHeartbeatEvent.screen == "app_boot")
                .scalar()
                or 0
            )
            top_routes_rows = (
                db.query(AdminRequestEvent.route, func.count(AdminRequestEvent.id).label("hits"))
                .group_by(AdminRequestEvent.route)
                .order_by(desc("hits"))
                .limit(7)
                .all()
            )

            traffic_last_hour = self._sum_traffic(db, hour_threshold)
            traffic_last_day = self._sum_traffic(db, day_threshold)
            traffic_last_week = self._sum_traffic(db, week_threshold)

            request_events = (
                db.query(AdminRequestEvent)
                .filter(AdminRequestEvent.happened_at >= week_threshold)
                .order_by(AdminRequestEvent.happened_at.asc())
                .all()
            )
            heartbeat_events = (
                db.query(AdminHeartbeatEvent)
                .filter(AdminHeartbeatEvent.happened_at >= week_threshold)
                .order_by(AdminHeartbeatEvent.happened_at.asc())
                .all()
            )

            uptime_seconds = max(
                0,
                int((now - _as_utc(stats.started_at or now)).total_seconds()),
            )

            return {
                "storage_mode": self._storage_mode,
                "active_unique_users": len(active_devices),
                "online_users": len(active_devices),
                "total_unique_users": int(total_unique_users),
                "peak_active_unique_users": int(stats.peak_active_devices or 0),
                "active_window_seconds": ACTIVE_WINDOW_SECONDS,
                "total_requests": int(stats.total_requests or 0),
                "requests_last_hour": int(requests_last_hour),
                "requests_last_24_hours": int(requests_last_day),
                "requests_last_7_days": int(requests_last_week),
                "total_heartbeats": int(stats.total_heartbeats or 0),
                "app_launches_total": int(app_launches_total),
                "total_request_bytes": int(stats.total_request_bytes or 0),
                "total_response_bytes": int(stats.total_response_bytes or 0),
                "total_traffic_bytes": int(stats.total_request_bytes or 0)
                + int(stats.total_response_bytes or 0),
                "traffic_last_hour_bytes": traffic_last_hour,
                "traffic_last_24_hours_bytes": traffic_last_day,
                "traffic_last_7_days_bytes": traffic_last_week,
                "uptime_seconds": uptime_seconds,
                "uptime_human": _humanize_seconds(uptime_seconds),
                "last_activity_at": _isoformat(stats.last_activity_at),
                "active_platforms": dict(
                    Counter(device.platform or "unknown" for device in active_devices)
                ),
                "active_app_versions": dict(
                    Counter(device.app_version or "unknown" for device in active_devices)
                ),
                "active_screens": dict(
                    Counter(device.current_screen or "unknown" for device in active_devices)
                ),
                "activity_series": {
                    "hour": self._build_series(
                        request_events,
                        heartbeat_events,
                        range_seconds=LAST_HOUR_SECONDS,
                        bucket_seconds=300,
                        label_format="%H:%M",
                    ),
                    "day": self._build_series(
                        request_events,
                        heartbeat_events,
                        range_seconds=LAST_DAY_SECONDS,
                        bucket_seconds=3600,
                        label_format="%H:%M",
                    ),
                    "week": self._build_series(
                        request_events,
                        heartbeat_events,
                        range_seconds=LAST_WEEK_SECONDS,
                        bucket_seconds=LAST_DAY_SECONDS,
                        label_format="%d.%m",
                    ),
                },
                "top_routes": [
                    {"path": route, "hits": int(hits)}
                    for route, hits in top_routes_rows
                ],
                "devices": [
                    self._device_to_dict(device, policies.get(device.device_id))
                    for device in devices
                ],
                "cameras_total": int(cameras_total),
                "cameras_streamable": int(cameras_streamable),
                "cameras_hidden": int(cameras_hidden),
                "cameras_offline": int(cameras_offline),
            }
        finally:
            db.close()

    def _sum_traffic(self, db: Session, threshold: datetime) -> int:
        row = (
            db.query(
                func.coalesce(func.sum(AdminRequestEvent.request_bytes), 0),
                func.coalesce(func.sum(AdminRequestEvent.response_bytes), 0),
            )
            .filter(AdminRequestEvent.happened_at >= threshold)
            .one()
        )
        return int((row[0] or 0) + (row[1] or 0))

    def _build_series(
        self,
        request_events: list[AdminRequestEvent],
        heartbeat_events: list[AdminHeartbeatEvent],
        *,
        range_seconds: int,
        bucket_seconds: int,
        label_format: str,
    ) -> list[dict[str, Any]]:
        now_ts = _now_ts()
        bucket_count = max(1, range_seconds // bucket_seconds)
        aligned_end = (int(now_ts) // bucket_seconds) * bucket_seconds + bucket_seconds
        range_start = aligned_end - range_seconds

        buckets: list[dict[str, Any]] = []
        for index in range(bucket_count):
            bucket_start = range_start + index * bucket_seconds
            buckets.append(
                {
                    "label": datetime.fromtimestamp(
                        bucket_start,
                        tz=timezone.utc,
                    ).strftime(label_format),
                    "requests": 0,
                    "heartbeats": 0,
                    "unique_devices": set(),
                }
            )

        for event in request_events:
            event_ts = event.happened_at.timestamp()
            if event_ts < range_start or event_ts >= aligned_end:
                continue
            bucket_index = int((event_ts - range_start) // bucket_seconds)
            if 0 <= bucket_index < bucket_count:
                buckets[bucket_index]["requests"] += 1

        for event in heartbeat_events:
            event_ts = event.happened_at.timestamp()
            if event_ts < range_start or event_ts >= aligned_end:
                continue
            bucket_index = int((event_ts - range_start) // bucket_seconds)
            if 0 <= bucket_index < bucket_count:
                buckets[bucket_index]["heartbeats"] += 1
                buckets[bucket_index]["unique_devices"].add(event.device_id)

        return [
            {
                "label": bucket["label"],
                "requests": bucket["requests"],
                "heartbeats": bucket["heartbeats"],
                "unique_devices": len(bucket["unique_devices"]),
            }
            for bucket in buckets
        ]

    def _policy_to_dict(self, policy: AdminAccessPolicy) -> dict[str, Any]:
        return {
            "device_id": policy.device_id,
            "map_access": bool(policy.map_access),
            "camera_access": bool(policy.camera_access),
            "free_access": bool(policy.free_access),
            "note": policy.note or "",
            "updated_at": _isoformat(policy.updated_at),
        }

    def _device_to_dict(
        self,
        device: AdminRuntimeDevice,
        policy: AdminAccessPolicy | None,
    ) -> dict[str, Any]:
        effective_policy = self._policy_to_dict(policy) if policy else {
            "device_id": device.device_id,
            **DEFAULT_ACCESS_POLICY,
            "updated_at": None,
        }
        return {
            "device_id": device.device_id,
            "platform": device.platform,
            "app_version": device.app_version,
            "current_screen": device.current_screen,
            "first_seen_at": _isoformat(device.first_seen_at),
            "last_seen_at": _isoformat(device.last_seen_at),
            "last_ip": device.last_ip,
            "heartbeat_count": int(device.heartbeat_count or 0),
            "request_count": int(device.request_count or 0),
            "total_request_bytes": int(device.total_request_bytes or 0),
            "total_response_bytes": int(device.total_response_bytes or 0),
            "policy": effective_policy,
        }


metrics_store = AdminRuntimeStore()


def require_admin_session(request: Request) -> str:
    auth_header = request.headers.get("authorization", "").strip()
    if not auth_header.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin bearer token is required",
        )
    token = auth_header.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin bearer token is required",
        )
    device_id = extract_device_id(request)
    metrics_store.validate_admin_session(device_id=device_id, token=token)
    return device_id
