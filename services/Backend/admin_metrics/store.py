"""AdminRuntimeStore core: init, recording, access policies, serialization."""

from __future__ import annotations

import json
import threading
from datetime import timedelta
from pathlib import Path
from typing import Any

from sqlalchemy import create_engine, func
from sqlalchemy.orm import Session, sessionmaker

from services.Backend.admin_metrics.models import (
    ADMIN_SESSION_ROW_ID,
    AdminAccessPolicy,
    AdminCameraCatalog,
    AdminHeartbeatEvent,
    AdminRequestEvent,
    AdminRuntimeDevice,
    AdminRuntimeStats,
    AdminSessionLock,
)
from services.Backend.admin_metrics.utils import (
    ACTIVE_WINDOW_SECONDS,
    _camera_fingerprint,
    _isoformat,
    _normalize_camera_stream_url,
    _safe_float,
    _utcnow,
)
from services.data_layer.database import Base, SessionLocal, engine

# Constants
ROOT = Path(__file__).resolve().parents[3]
FALLBACK_SQLITE_PATH = ROOT / "data" / "admin_runtime_fallback.db"
CAMERA_SOURCE_FILES = (
    ROOT / "public" / "cameras_nv_full.json",
    ROOT / "services" / "Frontend" / "assets" / "cameras_nv.json",
    ROOT / "public" / "cameras_nv.json",
)
DEFAULT_ACCESS_POLICY = {
    "map_access": True,
    "camera_access": True,
    "free_access": True,
    "note": "",
}


class AdminRuntimeStore:
    """DB-backed runtime metrics store suitable for production Postgres."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._engine = engine
        self._session_factory = SessionLocal
        self._initialized = False
        self._storage_mode = "postgres_runtime"

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
        source_path = next(
            (path for path in CAMERA_SOURCE_FILES if path.exists()), None
        )
        if source_path is None:
            return []

        try:
            payload = json.loads(source_path.read_text(encoding="utf-8"))
        except Exception:
            return []

        if not isinstance(payload, list):
            return []

        cameras_by_id: dict[str, dict[str, Any]] = {}
        for item in payload:
            if not isinstance(item, dict):
                continue
            lat = _safe_float(
                item.get("lat") if item.get("lat") is not None else item.get("latitude")
            )
            lng = _safe_float(
                item.get("lng") if item.get("lng") is not None else item.get("lon")
            )
            stream_url = _normalize_camera_stream_url(
                item.get("s") or item.get("stream_url") or item.get("url") or ""
            )
            if lat is None or lng is None or not stream_url:
                continue
            name = (
                str(item.get("n") or item.get("name") or "Камера").strip() or "Камера"
            )
            camera_id = _camera_fingerprint(
                name=name, lat=lat, lng=lng, stream_url=stream_url
            )
            candidate = {
                "camera_id": camera_id,
                "name": name[:255],
                "lat": lat,
                "lng": lng,
                "stream_url": stream_url[:2000],
                "is_secret": False,
                "streamable": item.get("streamable"),
                "provider": str(item.get("provider") or "").strip()[:64],
                "street": str(item.get("street") or "").strip()[:255],
                "district": str(item.get("district") or "").strip()[:255],
            }
            existing = cameras_by_id.get(camera_id)
            if existing is None:
                cameras_by_id[camera_id] = candidate
                continue
            if candidate.get("streamable") is not None:
                existing["streamable"] = candidate.get("streamable")
            if len(candidate["stream_url"]) > len(existing.get("stream_url") or ""):
                existing["stream_url"] = candidate["stream_url"]
            if candidate.get("provider") and not existing.get("provider"):
                existing["provider"] = candidate["provider"]
            if candidate.get("street") and not existing.get("street"):
                existing["street"] = candidate["street"]
            if candidate.get("district") and not existing.get("district"):
                existing["district"] = candidate["district"]
        return list(cameras_by_id.values())

    def _sync_camera_catalog_locked(self, db: Session) -> int:
        from services.Backend.admin_metrics.camera import AdminRuntimeStoreCameraMixin

        return AdminRuntimeStoreCameraMixin._sync_camera_catalog_impl(self, db)

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

    def _update_peak_active_devices(
        self, db: Session, stats: AdminRuntimeStats
    ) -> None:
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
                device.total_request_bytes = (
                    int(device.total_request_bytes or 0) + request_bytes
                )
                device.total_response_bytes = (
                    int(device.total_response_bytes or 0) + response_bytes
                )

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
                stats.total_request_bytes = (
                    int(stats.total_request_bytes or 0) + request_bytes
                )
                stats.total_response_bytes = (
                    int(stats.total_response_bytes or 0) + response_bytes
                )
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

                device.platform = (
                    platform or device.platform or "unknown"
                ).strip() or "unknown"
                device.app_version = (
                    app_version or device.app_version or "unknown"
                ).strip() or "unknown"
                device.current_screen = (
                    screen or device.current_screen or "unknown"
                ).strip() or "unknown"
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
        effective_policy = (
            self._policy_to_dict(policy)
            if policy
            else {
                "device_id": device.device_id,
                **DEFAULT_ACCESS_POLICY,
                "updated_at": None,
            }
        )
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
