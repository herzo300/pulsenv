"""Camera catalog and probing mixins for AdminRuntimeStore."""

from __future__ import annotations

import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from services.Backend.admin_metrics.models import AdminCameraCatalog
from services.Backend.admin_metrics.utils import (
    _isoformat,
    _utcnow,
)
from services.business.camera_stream_utils import (
    normalize_camera_stream_url,
    probe_camera_stream_url,
)

# Camera constants
CAMERA_PROBE_TIMEOUT_SECONDS = 6.0
CAMERA_PROBE_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
CAMERA_PROBE_MAX_WORKERS = max(
    4, min(24, int(os.getenv("CAMERA_PROBE_MAX_WORKERS", "16")))
)


class AdminRuntimeStoreCameraMixin:
    """Mixin providing camera catalog and probing functionality."""

    @staticmethod
    def _sync_camera_catalog_impl(store, db: Session) -> int:
        source_cameras = store._load_camera_source_rows()
        if not source_cameras:
            return 0

        existing = {row.camera_id: row for row in db.query(AdminCameraCatalog).all()}
        source_ids = {cam["camera_id"] for cam in source_cameras}
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

        for camera_id, row in existing.items():
            if camera_id not in source_ids:
                db.delete(row)
        return len(source_cameras)

    def _camera_source_index(self) -> dict[str, dict[str, Any]]:
        return {row["camera_id"]: row for row in self._load_camera_source_rows()}

    def _camera_to_dict(
        self,
        camera: AdminCameraCatalog,
        source_meta: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        source_meta = source_meta or {}
        is_secret = bool(source_meta.get("is_secret") is True)
        hidden_in_map = bool(camera.hidden_by_admin)
        return {
            "camera_id": camera.camera_id,
            "name": camera.name,
            "n": camera.name,
            "lat": float(camera.lat),
            "lng": float(camera.lng),
            "stream_url": camera.stream_url,
            "s": camera.stream_url,
            "streamable": bool(camera.streamable),
            "is_secret": is_secret,
            "visibility_tier": "secret" if is_secret else "public",
            "hidden_in_map": hidden_in_map,
            "hidden_by_admin": bool(camera.hidden_by_admin),
            "hidden_due_to_offline": bool(camera.hidden_due_to_offline),
            "provider": source_meta.get("provider") or None,
            "street": source_meta.get("street") or None,
            "district": source_meta.get("district") or None,
            "probe_http_status": camera.probe_http_status,
            "probe_error": (camera.probe_error or "")[:500],
            "last_checked_at": _isoformat(camera.last_checked_at),
            "updated_at": _isoformat(camera.updated_at),
        }

    def get_public_cameras(self) -> list[dict[str, Any]]:
        """All map-visible cameras (online + offline), excluding admin-hidden."""
        self.sync_camera_catalog()
        source_index = self._camera_source_index()
        if not source_index:
            return []

        db = self._db()
        try:
            db_rows = {
                row.camera_id: row
                for row in db.query(AdminCameraCatalog).all()
            }
            result: list[dict[str, Any]] = []
            for camera_id, meta in source_index.items():
                if bool(meta.get("is_secret") is True):
                    continue
                row = db_rows.get(camera_id)
                if row is not None:
                    if row.hidden_by_admin:
                        continue
                    result.append(self._camera_to_dict(row, meta))
                else:
                    result.append(self._camera_to_dict_from_source(meta))
            return result
        finally:
            db.close()

    def _camera_to_dict_from_source(self, meta: dict[str, Any]) -> dict[str, Any]:
        streamable = meta.get("streamable")
        if streamable is None:
            streamable = True
        return {
            "camera_id": meta.get("camera_id"),
            "name": meta.get("name"),
            "n": meta.get("name"),
            "lat": float(meta["lat"]),
            "lng": float(meta["lng"]),
            "stream_url": meta.get("stream_url"),
            "s": meta.get("stream_url"),
            "streamable": bool(streamable),
            "is_secret": False,
            "visibility_tier": "public",
            "hidden_in_map": False,
            "hidden_by_admin": False,
            "hidden_due_to_offline": not bool(streamable),
            "provider": meta.get("provider"),
            "street": meta.get("street"),
            "district": meta.get("district"),
        }

    def get_secret_cameras(self) -> list[dict[str, Any]]:
        self.sync_camera_catalog()
        source_index = self._camera_source_index()
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
            return [
                self._camera_to_dict(row, source_index.get(row.camera_id))
                for row in rows
                if bool(
                    (source_index.get(row.camera_id) or {}).get("is_secret") is True
                )
            ]
        finally:
            db.close()

    def get_admin_cameras(self) -> list[dict[str, Any]]:
        self.sync_camera_catalog()
        source_index = self._camera_source_index()
        db = self._db()
        try:
            rows = (
                db.query(AdminCameraCatalog)
                .order_by(AdminCameraCatalog.name.asc())
                .all()
            )
            return [
                self._camera_to_dict(row, source_index.get(row.camera_id))
                for row in rows
            ]
        finally:
            db.close()

    def _probe_camera_stream(
        self,
        *,
        camera_id: str,
        url: str,
        timeout_seconds: float,
    ) -> tuple[str, bool, int | None, str]:
        normalized = normalize_camera_stream_url(url)
        is_streamable, http_status, error_text, _ = probe_camera_stream_url(
            normalized,
            timeout_seconds=timeout_seconds,
        )
        return (camera_id, is_streamable, http_status, error_text)

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
        with ThreadPoolExecutor(
            max_workers=min(CAMERA_PROBE_MAX_WORKERS, max(1, len(snapshots))),
        ) as executor:
            futures = [
                executor.submit(
                    self._probe_camera_stream,
                    camera_id=camera_id,
                    url=url,
                    timeout_seconds=timeout_seconds,
                )
                for camera_id, url in snapshots
            ]
            for future in as_completed(futures):
                checks.append(future.result())

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

    def set_camera_hidden_by_admin(
        self, *, camera_id: str, hidden: bool
    ) -> dict[str, Any]:
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
