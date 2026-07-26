# services/Backend/routers/watchdog.py  — UPDATED with Frigate bridge
"""
Camera Watchdog API — exposes camera monitoring status & control.
Now supports both Frigate NVR bridge and legacy watchdog.
"""

import logging
from typing import Any, Dict

from fastapi import APIRouter

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/watchdog", tags=["watchdog"])


async def collect_watchdog_status() -> Dict[str, Any]:
    """Combined status: Frigate bridge + legacy watchdog + YOLO edge filter."""
    result: Dict[str, Any] = {}

    # 1. Frigate bridge status
    try:
        from services.frigate_bridge import get_bridge_status
        result["frigate"] = await get_bridge_status()
    except Exception as e:
        result["frigate"] = {"error": str(e), "available": False}

    # 2. Legacy watchdog status
    try:
        from services.camera_watchdog_service import (
            WATCHDOG_ENABLED, WATCHDOG_INTERVAL, WATCHDOG_MAX_CONCURRENCY,
        )
        result["legacy_watchdog"] = {
            "enabled": WATCHDOG_ENABLED,
            "interval": WATCHDOG_INTERVAL,
            "max_concurrency": WATCHDOG_MAX_CONCURRENCY,
        }
    except Exception as e:
        result["legacy_watchdog"] = {"error": str(e)}

    # 3. YOLO edge filter status
    try:
        from services.yolo_edge_filter import get_filter_status
        result["edge_filter"] = get_filter_status()
    except Exception as e:
        result["edge_filter"] = {"error": str(e)}

    # 4. SmolVLM status
    try:
        from services.smolvlm_service import get_status
        result["smolvlm"] = await get_status()
    except Exception as e:
        result["smolvlm"] = {"error": str(e)}

    return result


def collect_watchdog_alerts(limit: int = 20) -> Dict[str, Any]:
    """Recent camera alerts."""
    try:
        from services.camera_watchdog_service import get_recent_alerts

        alerts = get_recent_alerts(limit=limit)
        return {"alerts": alerts, "count": len(alerts)}
    except Exception as e:
        return {"alerts": [], "count": 0, "error": str(e)}


async def run_watchdog_scan(max_cameras: int = 5) -> Dict[str, Any]:
    """Manually trigger a camera scan cycle (legacy mode)."""
    try:
        from services.camera_watchdog_service import run_watchdog_cycle

        alerts = await run_watchdog_cycle(bot=None, max_cameras=max_cameras)
        return {
            "scanned": max_cameras,
            "alerts_found": len(alerts),
            "alerts": [
                {
                    "camera": a.get("camera_name"),
                    "type": a.get("event_type"),
                    "confidence": a.get("confidence"),
                    "description": a.get("description"),
                }
                for a in alerts
            ],
        }
    except Exception as e:
        logger.error("Manual scan error: %s", e)
        return {"error": str(e)}


@router.get("/status")
async def watchdog_status() -> Dict[str, Any]:
    return await collect_watchdog_status()

@router.post("/auto-heal")
async def trigger_auto_healing() -> Dict[str, Any]:
    """Trigger diagnostic sweep & auto-healing across 9 Docker services."""
    try:
        from services.auto_healing_engine import auto_healing
        return await auto_healing.run_diagnostics_and_heal()
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@router.get("/alerts")
async def get_alerts(limit: int = 20) -> Dict[str, Any]:
    return collect_watchdog_alerts(limit=limit)


@router.post("/scan")
async def trigger_scan(max_cameras: int = 5) -> Dict[str, Any]:
    return await run_watchdog_scan(max_cameras=max_cameras)


@router.get("/frigate/health")
async def frigate_health() -> Dict[str, Any]:
    """Direct Frigate NVR health check."""
    try:
        from services.frigate_bridge import check_frigate_health
        return await check_frigate_health()
    except Exception as e:
        return {"healthy": False, "error": str(e)}
