# services/Backend/routers/telegram_router.py
"""
Telegram monitor management endpoints: status, messages.

Мониторинг запускается отдельным контейнером `monitoring`
(services/monitoring/main.py). Запуск/остановка из API удалены:
legacy-монитор TelegramMonitor (services/telegram_monitor.py) удалён,
дублировал активный пайплайн telegram_handler.py без фильтра каналов.
Статистика теперь читается из БД reports по источникам tg:*.
"""

import logging
import os

from fastapi import APIRouter, Query, Request

from ..security import require_admin_api_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/telegram", tags=["telegram"])
TELEGRAM_BOT_TOKEN: str = os.getenv("TG_BOT_TOKEN", "")


@router.get("/monitor/status")
async def get_telegram_monitor_status(request: Request):
    """Статистика Telegram-мониторинга из БД (источники tg:*)."""
    require_admin_api_token(request)
    from services.data_layer.database import get_db

    try:
        db = next(get_db())
        try:
            from sqlalchemy import func

            from services.data_layer.models import Report

            total = (
                db.query(func.count(Report.id))
                .filter(Report.source.like("tg:%"))
                .scalar()
            ) or 0
            by_channel_rows = (
                db.query(Report.telegram_channel, func.count(Report.id))
                .filter(Report.source.like("tg:%"))
                .group_by(Report.telegram_channel)
                .all()
            )
            return {
                "status": "running",
                "statistics": {
                    "total_messages": total,
                    "by_category": {},
                    "by_channel": {ch or "unknown": cnt for ch, cnt in by_channel_rows},
                    "recent": [],
                },
            }
        finally:
            db.close()
    except Exception as e:
        logger.error("Failed to collect Telegram monitor stats: %s", e)
        return {
            "status": "unknown",
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
    """Последние сообщения из TG-источников (таблица reports)."""
    require_admin_api_token(request)
    from services.data_layer.database import get_db

    try:
        db = next(get_db())
        try:
            from services.data_layer.models import Report

            query = db.query(Report).filter(Report.source.like("tg:%"))
            if category:
                query = query.filter(Report.category == category)
            reports = (
                query.order_by(Report.created_at.desc())
                .offset(offset)
                .limit(limit)
                .all()
            )
            messages = [
                {
                    "id": r.id,
                    "title": r.title,
                    "description": (r.description or "")[:300],
                    "category": r.category,
                    "channel": r.telegram_channel,
                    "created_at": r.created_at.isoformat() if r.created_at else None,
                }
                for r in reports
            ]
            return {"success": True, "messages": messages, "count": len(messages)}
        finally:
            db.close()
    except Exception as e:
        logger.error("Error getting Telegram messages: %s", e)
        return {"success": False, "error": str(e), "messages": []}
