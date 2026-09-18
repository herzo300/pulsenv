#!/usr/bin/env python3
"""Camera streamability probe launcher.

Refreshes camera availability flags for the public camera layer.
No image analysis, event detection, or background surveillance is started here.
"""

from __future__ import annotations

import logging
import os
import sys
import time

from dotenv import load_dotenv

load_dotenv()

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

from services.Backend.admin_metrics import metrics_store

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("camera_probe")

PROBE_INTERVAL_SEC = max(60, int(os.getenv("CAMERA_PROBE_INTERVAL_SEC", "300")))
_last_hidden_count: int | None = None


def _send_probe_alert(message: str) -> None:
    """Локальный лог оповещения камер (внешние webhook/Slack/ntfy отключены)."""
    logger.warning("PROBE ALERT: %s", message)


def camera_probe_loop() -> None:
    """Camera streamability probe."""
    global _last_hidden_count
    logger.info("Camera probe loop started, interval=%ss", PROBE_INTERVAL_SEC)
    while True:
        try:
            result = metrics_store.refresh_camera_streamability()
            hidden = int(result.get("hidden") or 0)
            total = int(result.get("total") or 0)
            logger.info(
                "Camera probe complete: total=%s streamable=%s hidden=%s checked_at=%s",
                result.get("total"),
                result.get("streamable"),
                result.get("hidden"),
                result.get("checked_at"),
            )
            if _last_hidden_count is not None and hidden > _last_hidden_count:
                delta = hidden - _last_hidden_count
                _send_probe_alert(
                    f"📷 Камеры: offline {hidden}/{total} (+{delta}). "
                    "Проверьте Viseron и camera_probe."
                )
            _last_hidden_count = hidden
        except Exception as exc:
            logger.exception("Camera probe failed: %s", exc)
            _send_probe_alert(f"📷 Camera probe error: {exc}")
        time.sleep(PROBE_INTERVAL_SEC)


def camera_frame_cacher_loop() -> None:
    """Periodically captures and caches frames for all streamable public cameras."""
    enable_cacher = os.getenv("ENABLE_CAMERA_FRAME_CACHER", "false").lower() == "true"
    if not enable_cacher:
        logger.info("Camera frame cacher is disabled via ENABLE_CAMERA_FRAME_CACHER=false. Cacher thread exiting.")
        return

    logger.info("Camera frame cacher loop started")
    try:
        from services.data_layer.database import SessionLocal
        from services.Backend.admin_metrics.models import AdminCameraCatalog
        from services.Backend.routers.vlm import _capture_frame_from_url
        from services.business.camera_frame_cache import set_cached_frame
        from concurrent.futures import ThreadPoolExecutor
    except Exception as exc:
        logger.error("Failed to import VLM caching dependencies: %s", exc)
        return

    while True:
        try:
            db = SessionLocal()
            try:
                # Fetch public streamable cameras that are not hidden by admin
                cameras = (
                    db.query(AdminCameraCatalog)
                    .filter(AdminCameraCatalog.streamable.is_(True))
                    .filter(AdminCameraCatalog.hidden_by_admin.is_(False))
                    .all()
                )
                active_cameras = [(c.camera_id, c.stream_url) for c in cameras]
            finally:
                db.close()

            if active_cameras:
                logger.info("Caching frames for %d active cameras...", len(active_cameras))

                def cache_single_camera(cam_id: str, stream_url: str) -> None:
                    try:
                        frame_bytes = _capture_frame_from_url(stream_url, timeout=8)
                        if frame_bytes:
                            set_cached_frame(stream_url, frame_bytes)
                    except Exception as e:
                        logger.warning("Failed to cache frame for camera %s: %s", cam_id, e)

                with ThreadPoolExecutor(max_workers=min(8, len(active_cameras))) as executor:
                    futures = [
                        executor.submit(cache_single_camera, cam_id, stream_url)
                        for cam_id, stream_url in active_cameras
                    ]
                    for fut in futures:
                        try:
                            fut.result()
                        except Exception:
                            pass
                logger.info("Camera frame cacher cycle complete.")
        except Exception as exc:
            logger.exception("Camera frame cacher loop error: %s", exc)

        time.sleep(60)


def main() -> None:
    import threading

    cacher_thread = threading.Thread(target=camera_frame_cacher_loop, daemon=True)
    cacher_thread.start()
    camera_probe_loop()


if __name__ == "__main__":
    main()
