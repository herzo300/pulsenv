from fastapi import APIRouter, Depends, Query, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import select, or_, and_
from datetime import datetime, timedelta
import math
from typing import List, Optional, Dict, Any

from services.data_layer.database import get_db
from services.data_layer.models import JkhIncident, GeoSubscription

router = APIRouter(prefix="/api/v1/jkh", tags=["jkh_outages"])


def _calculate_remaining_text(expires_at: Optional[datetime]) -> tuple[int, str]:
    """Возвращает оставшиеся секунды и красивую текстовую строку для таймера."""
    if not expires_at:
        return 0, "Работы завершаются"
    
    now = datetime.utcnow()
    diff = (expires_at - now).total_seconds()
    if diff <= 0:
        return 0, "Восстановление подачи..."
    
    hours = int(diff // 3600)
    minutes = int((diff % 3600) // 60)
    
    if hours > 0:
        remaining_text = f"через {hours}ч {minutes}мин"
    else:
        remaining_text = f"через {minutes}мин"
        
    return int(diff), remaining_text


def _get_type_info(incident_type: str) -> dict:
    types = {
        "water": {
            "title": "Горячее водоснабжение",
            "short_name": "Горячая вода",
            "icon": "water_drop",
            "color": "#3B82F6",
        },
        "cold_water": {
            "title": "Холодное водоснабжение",
            "short_name": "Холодная вода",
            "icon": "water",
            "color": "#06B6D4",
        },
        "heating": {
            "title": "Отопление",
            "short_name": "Отопление",
            "icon": "thermostat",
            "color": "#EF4444",
        },
        "electricity": {
            "title": "Электроснабжение",
            "short_name": "Электричество",
            "icon": "bolt",
            "color": "#EAB308",
        },
        "gas": {
            "title": "Газоснабжение",
            "short_name": "Газ",
            "icon": "propane_tank",
            "color": "#F97316",
        },
    }
    return types.get(incident_type.lower(), {
        "title": "Коммунальная услуга",
        "short_name": "ЖКХ",
        "icon": "build",
        "color": "#8B5CF6",
    })


@router.get("/incidents")
def list_jkh_incidents(
    city: str = Query("nizhnevartovsk", description="Город"),
    status: str = Query("active", description="active / all / resolved"),
    db: Session = Depends(get_db),
):
    """Список текущих плановых и аварийных отключений ЖКХ."""
    query = db.query(JkhIncident)
    
    if status == "active":
        query = query.filter(JkhIncident.status == "active")
        
    incidents = query.order_by(JkhIncident.started_at.desc()).all()
    
    # Если база пуста — отдать актуальные предзаполненные данные для демо
    if not incidents:
        incidents = _get_seed_incidents(db)
        
    result = []
    for inc in incidents:
        rem_sec, rem_text = _calculate_remaining_text(inc.expires_at)
        type_info = _get_type_info(inc.incident_type)
        
        result.append({
            "id": inc.id,
            "title": inc.title,
            "description": inc.description,
            "address": inc.address,
            "lat": inc.lat,
            "lng": inc.lng,
            "incident_type": inc.incident_type,
            "type_title": type_info["title"],
            "short_name": type_info["short_name"],
            "icon": type_info["icon"],
            "color_hex": type_info["color"],
            "status": inc.status,
            "started_at": inc.started_at.isoformat() if inc.started_at else None,
            "expires_at": inc.expires_at.isoformat() if inc.expires_at else None,
            "remaining_seconds": rem_sec,
            "remaining_text": rem_text,
            "display_timer": f"{type_info['short_name']} вернется {rem_text}",
        })
        
    return {"incidents": result, "total": len(result)}


@router.get("/house-status")
def get_house_status(
    address: Optional[str] = Query(None, description="Адрес дома пользователя"),
    lat: Optional[float] = Query(None, description="Широта дома"),
    lng: Optional[float] = Query(None, description="Долгота дома"),
    db: Session = Depends(get_db),
):
    """
    Возвращает статус ЖКХ дома пользователя:
    🟢 normal (#22C55E) — Всё в норме
    🟡 planned (#EAB308) — Плановые работы
    🔴 emergency (#EF4444) — Аварийное отключение
    """
    incidents = db.query(JkhIncident).filter(JkhIncident.status == "active").all()
    if not incidents:
        incidents = _get_seed_incidents(db)
        
    matching_incidents = []
    
    for inc in incidents:
        is_match = False
        # Проверка по адресу
        if address and inc.address and (address.lower() in inc.address.lower() or inc.address.lower() in address.lower()):
            is_match = True
        # Проверка по координатам (радиус ~350м)
        elif lat and lng and inc.lat and inc.lng:
            dist = _haversine_distance(lat, lng, inc.lat, inc.lng)
            if dist <= 350:
                is_match = True
                
        if is_match:
            matching_incidents.append(inc)

    # Если инцидентов для дома нет — честный «зелёный» статус,
    # без подсовывания первого попавшегося инцидента «для наглядности»

    if not matching_incidents:
        return {
            "status": "normal",
            "status_code": "GREEN",
            "color_hex": "#22C55E",
            "aura_color": "#22C55E",
            "status_title": "Всё в норме",
            "status_description": "Коммунальные службы работают в штатном режиме. Отключений не зафиксировано.",
            "primary_timer": "",
            "outages": [],
        }

    # Анализируем найденные инциденты
    has_emergency = any("авар" in (inc.title + (inc.description or "")).lower() for inc in matching_incidents)
    status_type = "emergency" if has_emergency else "planned"
    status_code = "RED" if has_emergency else "YELLOW"
    color_hex = "#EF4444" if has_emergency else "#EAB308"
    status_title = "Аварийное отключение" if has_emergency else "Плановые работы"

    outages_list = []
    for inc in matching_incidents:
        rem_sec, rem_text = _calculate_remaining_text(inc.expires_at)
        type_info = _get_type_info(inc.incident_type)
        
        outages_list.append({
            "id": inc.id,
            "title": inc.title,
            "description": inc.description,
            "address": inc.address,
            "incident_type": inc.incident_type,
            "type_title": type_info["title"],
            "short_name": type_info["short_name"],
            "icon": type_info["icon"],
            "color_hex": type_info["color"],
            "remaining_seconds": rem_sec,
            "remaining_text": rem_text,
            "display_timer": f"{type_info['short_name']} вернется {rem_text}",
        })

    primary_timer = outages_list[0]["display_timer"] if outages_list else ""

    return {
        "status": status_type,
        "status_code": status_code,
        "color_hex": color_hex,
        "aura_color": color_hex,
        "status_title": status_title,
        "status_description": f"По вашему адресу {matching_incidents[0].address or 'в микрорайоне'} зафиксировано {len(matching_incidents)} ограничение(й).",
        "primary_timer": primary_timer,
        "outages": outages_list,
    }


def _haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Дистанция в метрах."""
    R = 6371000.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def _get_seed_incidents(db: Session) -> List[JkhIncident]:
    """Сид-инциденты удалены: фейковые «вечно активные» отключения
    дезинформировали пользователей. Пустая база = честное «отключений нет»."""
    return []
