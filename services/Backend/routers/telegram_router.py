# services/Backend/routers/telegram_router.py
"""
Telegram monitor management endpoints: start, stop, status, messages.
"""

import logging
import os
from typing import Optional

from fastapi import APIRouter, Query, Request

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/telegram", tags=["telegram"])
TELEGRAM_BOT_TOKEN: str = os.getenv("TG_BOT_TOKEN", "")


@router.post("/monitor/start")
async def start_telegram_monitor(config: dict, request: Request):
    """Start monitoring Telegram channels."""
    try:
        from backend.database import get_db
        from services.telegram_monitor import start_telegram_monitoring

        # Get a fresh DB session for the monitor
        db_gen = get_db()
        db = next(db_gen)

        monitor = await start_telegram_monitoring(
            channels=config.get("channels", []),
            api_id=config.get("api_id", 0),
            api_hash=config.get("api_hash", ""),
            phone=config.get("phone", ""),
            bot_token=TELEGRAM_BOT_TOKEN,
            db=db,
        )
        request.app.state.telegram_monitor = monitor
        channels = config.get("channels", [])
        logger.info("Telegram monitor started for %d channels", len(channels))
        return {
            "success": True,
            "message": f"Мониторинг запущен для {len(channels)} каналов",
            "channels": channels,
        }
    except Exception as e:
        logger.error("Failed to start Telegram monitor: %s", e)
        return {"success": False, "error": str(e)}


@router.get("/monitor/status")
async def get_telegram_monitor_status(request: Request):
    """Get Telegram monitor status and statistics."""
    monitor = getattr(request.app.state, "telegram_monitor", None)
    if monitor:
        return {"status": "running", "statistics": monitor.get_statistics()}
    return {
        "status": "stopped",
        "statistics": {
            "total_messages": 0,
            "by_category": {},
            "by_channel": {},
            "recent": [],
        },
    }


@router.get("/monitor/messages")
async def get_telegram_messages(
    request: Request,
    category: Optional[str] = None,
    limit: int = Query(100, le=100),
    offset: int = Query(0, ge=0),
):
    """Get filtered messages from the Telegram monitor."""
    monitor = getattr(request.app.state, "telegram_monitor", None)
    if not monitor:
        return {
            "success": False,
            "error": "Telegram монитор не запущен",
            "messages": [],
        }
    try:
        messages = monitor.get_filtered_messages(category=category, limit=limit)
        return {"success": True, "messages": messages, "count": len(messages)}
    except Exception as e:
        logger.error("Error getting Telegram messages: %s", e)
        return {"success": False, "error": str(e), "messages": []}


@router.post("/monitor/stop")
async def stop_telegram_monitor(request: Request):
    """Stop the Telegram monitor."""
    monitor = getattr(request.app.state, "telegram_monitor", None)
    if monitor:
        await monitor.stop()
        request.app.state.telegram_monitor = None
        logger.info("Telegram monitor stopped.")
        return {"success": True, "message": "Мониторинг остановлен"}
    return {"success": False, "error": "Мониторинг не запущен"}
