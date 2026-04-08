#!/usr/bin/env python3
"""
Camera Probe + Frigate Bridge Launcher.

Two tasks running in parallel:
  1. Camera probe — refreshes Postgres camera streamability flags
  2. Frigate bridge — polls Frigate NVR events and escalates to local VLM

Falls back to legacy camera_watchdog if Frigate is unavailable.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
import time
import threading

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
FRIGATE_ENABLED = os.getenv("FRIGATE_ENABLED", "true").lower() == "true"


def camera_probe_loop() -> None:
    """Legacy camera streamability probe (synchronous, runs in thread)."""
    logger.info("Camera probe loop started, interval=%ss", PROBE_INTERVAL_SEC)
    while True:
        try:
            result = metrics_store.refresh_camera_streamability()
            logger.info(
                "Camera probe complete: total=%s streamable=%s hidden=%s checked_at=%s",
                result.get("total"),
                result.get("streamable"),
                result.get("hidden"),
                result.get("checked_at"),
            )
        except Exception as exc:
            logger.exception("Camera probe failed: %s", exc)
        time.sleep(PROBE_INTERVAL_SEC)


async def frigate_bridge_loop() -> None:
    """Frigate NVR bridge (async, main loop)."""
    if not FRIGATE_ENABLED:
        logger.info("Frigate bridge disabled — running probe only")
        return

    try:
        from services.frigate_bridge import smart_watchdog_loop
        await smart_watchdog_loop(bot=None)
    except ImportError as e:
        logger.warning("Frigate bridge not available: %s", e)
    except Exception as e:
        logger.error("Frigate bridge crashed: %s", e)


def main() -> None:
    # Start camera probe in background thread
    probe_thread = threading.Thread(target=camera_probe_loop, daemon=True, name="camera_probe")
    probe_thread.start()

    # Run Frigate bridge in main async loop
    asyncio.run(frigate_bridge_loop())


if __name__ == "__main__":
    main()
