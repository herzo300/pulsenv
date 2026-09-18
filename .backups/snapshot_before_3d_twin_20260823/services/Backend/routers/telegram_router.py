# services/Backend/routers/telegram_router.py
"""
Telegram monitor management endpoints: start, stop, status, messages.
"""

import logging
import os

from fastapi import APIRouter, Query, Request
from pydantic import BaseModel, Field

from ..security import require_admin_api_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/telegram", tags=["telegram"])
TELEGRAM_BOT_TOKEN: str = os.getenv("TG_BOT_TOKEN", "")


class TelegramMonitorConfig(BaseModel):
    channels: list[str] = Field(default_factory=list)
    api_id: int = 0
    api_hash: str = ""
    phone: str = ""


@router.post("/monitor/start")
async def start_telegram_monitor(config: TelegramMonitorConfig, request: Request):
    """Start monitoring Telegram channels."""
    require_admin_api_token(request)
    try:
        from services.data_layer.database import get_db
        from services.telegram_monitor import start_telegram_monitoring

        # Get a fresh DB session for the monitor
        db_gen = get_db()
        db = next(db_gen)

        monitor = await start_telegram_monitoring(
            channels=config.channels,
            api_id=config.api_id,
            api_hash=config.api_hash,
            phone=config.phone,
            bot_token=TELEGRAM_BOT_TOKEN,
            db=db,
        )
        request.app.state.telegram_monitor = monitor
        channels = config.channels
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
    require_admin_api_token(request)
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
    category: str | None = None,
    limit: int = Query(100, le=100),
    offset: int = Query(0, ge=0),
):
    """Get filtered messages from the Telegram monitor."""
    require_admin_api_token(request)
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
    require_admin_api_token(request)
    monitor = getattr(request.app.state, "telegram_monitor", None)
    if monitor:
        await monitor.stop()
        request.app.state.telegram_monitor = None
        logger.info("Telegram monitor stopped.")
        return {"success": True, "message": "Мониторинг остановлен"}
    return {"success": False, "error": "Мониторинг не запущен"}
