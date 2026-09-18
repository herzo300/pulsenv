"""
geo_subscriptions.py — Geo-fencing Push Alerts & Subscriptions router for City Pulse / Пульс Города.
Follows fastapi-pro & notification-router skills.
"""
import math
import logging
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from services.data_layer.database import get_db
from services.data_layer.models import GeoSubscription, Report, User
from services.data_layer.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/geo-subscriptions", tags=["geo-subscriptions"])


def haversine_distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate great-circle distance between two points in meters."""
    R = 6371000.0  # Earth radius in meters
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


class CreateGeoSubscriptionRequest(BaseModel):
    lat: float = Field(..., description="Latitude of central point")
    lng: float = Field(..., description="Longitude of central point")
    radius_m: int = Field(default=1000, description="Geo-fence radius in meters (default 1000m)")
    label: Optional[str] = Field(default="Мой район", description="User-friendly zone label (e.g. Дом, Работа)")
    categories: Optional[str] = Field(default=None, description="Comma-separated category filters (or null for all)")
    telegram_id: Optional[int] = Field(default=None, description="Telegram ID for push delivery")


class GeoSubscriptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    telegram_id: int
    lat: float
    lng: float
    radius_m: int
    label: Optional[str]
    categories: Optional[str]
    is_active: bool
    created_at: datetime


class MatchReportRequest(BaseModel):
    report_id: Optional[int] = None
    lat: float
    lng: float
    category: str
    title: str


@router.post("", response_model=GeoSubscriptionResponse, status_code=201)
async def create_geo_subscription(
    req: CreateGeoSubscriptionRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """
    Создает новую гео-зону подписки на уведомления для пользователя (Geo-fencing push alert).
    При появлении сигналов в этой гео-зоне отправляется таргетированное PUSH/Telegram-уведомление.
    """
    tg_id = req.telegram_id
    if not tg_id and current_user:
        tg_id = current_user.telegram_id
    if not tg_id:
        tg_id = 999000  # Fallback default user ID

    sub = GeoSubscription(
        telegram_id=tg_id,
        lat=req.lat,
        lng=req.lng,
        radius_m=req.radius_m,
        label=req.label or "Мой район",
        categories=req.categories,
        is_active=True,
        created_at=datetime.utcnow()
    )
    db.add(sub)
    db.commit()
    db.refresh(sub)

    logger.info(f"[GEO-FENCE] Created geo subscription #{sub.id} for user {tg_id} around ({sub.lat}, {sub.lng}), radius={sub.radius_m}m")
    return sub


@router.get("", response_model=List[GeoSubscriptionResponse])
async def list_geo_subscriptions(
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """Возвращает список активных гео-зон подписок текущего пользователя."""
    tg_id = current_user.telegram_id if current_user else None
    query = db.query(GeoSubscription).filter(GeoSubscription.is_active.is_(True))
    if tg_id:
        query = query.filter(GeoSubscription.telegram_id == tg_id)
    return query.all()


@router.delete("/{subscription_id}", status_code=200)
async def delete_geo_subscription(
    subscription_id: int,
    db: Session = Depends(get_db)
):
    """Удаляет/деактивирует гео-зону подписки."""
    sub = db.query(GeoSubscription).filter(GeoSubscription.id == subscription_id).first()
    if not sub:
        raise HTTPException(status_code=404, detail="Geo-subscription not found")

    sub.is_active = False
    db.commit()
    return {"status": "ok", "message": f"Geo-subscription #{subscription_id} deactivated"}


@router.post("/match")
async def match_report_to_geofences(
    req: MatchReportRequest,
    db: Session = Depends(get_db)
):
    """
    Проверяет координаты нового сигнала на вхождение в гео-зоны подписчиков (Geofencing Match Engine).
    Возвращает список ID подписчиков, чьи гео-зоны покрывают данное происшествие.
    """
    active_subs = db.query(GeoSubscription).filter(GeoSubscription.is_active.is_(True)).all()
    matched_subscribers = []

    for sub in active_subs:
        dist_m = haversine_distance_m(req.lat, req.lng, sub.lat, sub.lng)
        if dist_m <= sub.radius_m:
            # Check category filter if specified
            if sub.categories:
                allowed_cats = [c.strip().lower() for c in sub.categories.split(",")]
                if req.category.lower() not in allowed_cats:
                    continue
            matched_subscribers.append({
                "subscription_id": sub.id,
                "telegram_id": sub.telegram_id,
                "distance_m": round(dist_m, 1),
                "label": sub.label
            })

    return {
        "status": "ok",
        "matched_count": len(matched_subscribers),
        "matches": matched_subscribers
    }
