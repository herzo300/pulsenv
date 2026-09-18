import logging
from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import Report, User, VipSubscription

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/profile", tags=["profile"])


def _tier_name(sub: VipSubscription | None) -> str:
    return "Бесплатный"


@router.get("/{telegram_id}")
async def get_user_profile(telegram_id: int, db: Session = Depends(get_db)):
    """Return a mobile-friendly profile snapshot."""
    try:
        user = db.query(User).filter(User.telegram_id == telegram_id).first()
        if not user:
            user = User(telegram_id=telegram_id, username=f"User_{telegram_id}")
            db.add(user)
            db.commit()
            db.refresh(user)

        reports_query = db.query(Report).filter(Report.user_id == user.id)
        reports_count = reports_query.count()
        reports_on_map = reports_query.filter(
            Report.lat.isnot(None), Report.lng.isnot(None)
        ).count()
        reports_resolved = reports_query.filter(Report.status == "resolved").count()

        # Simple rank by number of submitted reports.
        ranked_users = (
            db.query(Report.user_id, func.count(Report.id).label("report_count"))
            .filter(Report.user_id.isnot(None))
            .group_by(Report.user_id)
            .order_by(func.count(Report.id).desc())
            .all()
        )
        activity_rank = 0
        for index, row in enumerate(ranked_users, start=1):
            if row.user_id == user.id:
                activity_rank = index
                break

        vip_sub = db.query(VipSubscription).filter(VipSubscription.telegram_id == user.telegram_id).first()
        is_vip = vip_sub is not None and vip_sub.tier == "vip"
        
        from datetime import datetime
        today_str = datetime.now().strftime("%Y-%m-%d")
        
        if user.ai_tasks_last_reset != today_str:
            if is_vip:
                user.ai_tasks_remaining += 10
            else:
                user.ai_tasks_remaining = 3
            user.ai_tasks_last_reset = today_str
            db.commit()
            
        ai_minutes_total = 10 if is_vip else 3
        ai_minutes_used = 0
        ai_minutes_remaining = user.ai_tasks_remaining
        is_track_active = vip_sub.is_track_active if vip_sub else False
        tariff_expiry = "2030-01-01T00:00:00" if is_vip else None
        searches_limit = vip_sub.searches_limit if vip_sub else 3
        searches_used = vip_sub.searches_used if vip_sub else 0

        monitoring_hours_left = round(ai_minutes_remaining / 60.0, 1)


        general_features = [
            {
                "name": "Карта города",
                "description": "Живые маркеры проблем, событий, камер и инфраструктуры на карте.",
                "available": True,
            },
            {
                "name": "Сообщить о проблеме",
                "description": "Быстрая отправка сигнала с фото, адресом и AI-подсказками.",
                "available": True,
            },
            {
                "name": "Открытые данные",
                "description": "Статистика и городские датасеты без отдельной подписки.",
                "available": True,
            },
            {
                "name": "Рейтинг УК",
                "description": "Список управляющих компаний, оценки и контакты.",
                "available": True,
            },
        ]

        vip_features = [
            {
                "name": "Расширенный доступ к камерам",
                "description": "Каталог городских камер, проверка доступности потоков и приоритетная поддержка.",
                "available": is_vip or ai_minutes_remaining > 0,
            },
            {
                "name": "Приоритетная обработка",
                "description": "Быстрый путь для AI-аналитики и обработки обращений.",
                "available": is_vip,
            },
            {
                "name": "Скрытые и служебные камеры",
                "description": "Расширенный каталог камер и служебные настройки доступа.",
                "available": is_vip,
            },
        ]

        return {
            "success": True,
            "profile": {
                "user_id": user.id,
                "telegram_id": user.telegram_id,
                "reports_submitted": reports_count,
                "reports_on_map": reports_on_map,
                "reports_resolved": reports_resolved,
                "activity_rank": activity_rank,
                "is_vip": is_vip,
                "tariff_name": _tier_name(sub),
                "tariff_expiry": tariff_expiry,
                "is_track_active": is_track_active,
                "monitoring_hours_left": monitoring_hours_left,
                "monitoring_minutes_left": ai_minutes_remaining,
                "ai_monitoring_balance": {
                    "total_minutes_allowed": ai_minutes_total,
                    "used_minutes": ai_minutes_used,
                    "remaining_minutes": ai_minutes_remaining,
                },
                "visual_searches_balance": {
                    "limit": searches_limit,
                    "used": searches_used,
                    "remaining": max(0, searches_limit - searches_used),
                },
            },
            "features": {
                "general": general_features,
                "vip": vip_features,
            },
        }
    except Exception as exc:
        logger.warning("Profile fetch error for %s: %s", telegram_id, exc)
        return {
            "success": True,
            "profile": {
                "user_id": None,
                "telegram_id": telegram_id,
                "reports_submitted": 0,
                "reports_on_map": 0,
                "reports_resolved": 0,
                "activity_rank": 0,
                "is_vip": False,
                "tariff_name": "Базовый",
                "tariff_expiry": None,
                "is_track_active": False,
                "monitoring_hours_left": 0.0,
                "monitoring_minutes_left": 0,
                "ai_monitoring_balance": {
                    "total_minutes_allowed": 0,
                    "used_minutes": 0,
                    "remaining_minutes": 0,
                },
                "visual_searches_balance": {
                    "limit": 0,
                    "used": 0,
                    "remaining": 0,
                },
            },
            "features": {
                "general": [],
                "vip": [],
            },
        }
