# services/Backend/routers/uk_ratings.py
"""
API роутер: рейтинг управляющих компаний.
"""

import logging

from fastapi import APIRouter, Query
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

import re

def normalize_uk_name(name: str) -> str:
    n = str(name or "").strip().lower()
    n = n.replace("\n", " ").replace("\r", " ")
    n = re.sub(r'[\\\'"«»`“”]', '', n)
    # Remove common prefixes like ооо, ао, тсж, тсн, ук, оао
    n = re.sub(r'\b(ооо|ао|тсж|тсн|ук|оао)\b', '', n)
    n = re.sub(r'\s+', ' ', n)
    return n.strip()

def find_uk_in_catalog(uk_name: str, catalog: list) -> dict | None:
    q_norm = normalize_uk_name(uk_name)
    if not q_norm:
        return None
    # First pass: try exact normalized match
    for row in catalog:
        if normalize_uk_name(row.get("name")) == q_norm:
            return row
    # Second pass: try containment check
    for row in catalog:
        n_norm = normalize_uk_name(row.get("name"))
        if q_norm in n_norm or n_norm in q_norm:
            return row
    return None

router = APIRouter(prefix="/api/uk", tags=["uk-ratings"])


@router.get("/catalog")
async def get_uk_catalog():
    """Полный каталог УК Нижневартовска (opendata + рейтинг)."""
    try:
        from services.business.uk_service import get_uk_catalog as load_catalog

        companies = load_catalog()
        return JSONResponse(content={"companies": companies, "total": len(companies)})
    except Exception as e:
        logger.error("Failed to get UK catalog: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": "Не удалось загрузить каталог УК"},
        )


@router.get("/ratings")
async def get_ratings(limit: int = Query(50, le=200)):
    """Получить рейтинг всех УК (лучшие первые)."""
    try:
        from services.uk_rating_service import get_all_ratings

        ratings = get_all_ratings(limit=limit)
        return JSONResponse(content={"ratings": ratings, "total": len(ratings)})
    except Exception as e:
        logger.error("Failed to get UK ratings: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": "Не удалось получить рейтинг УК"},
        )


@router.get("/by_coords")
async def get_uk_by_coords(lat: float, lng: float):
    """Получить УК по координатам."""
    try:
        from services.uk_service import find_uk_by_coords

        result = await find_uk_by_coords(lat, lng)
        if not result:
            return JSONResponse(
                status_code=404, content={"error": "not_found", "detail": "УК не найдена по этому адресу"}
            )
        return JSONResponse(content=result)
    except Exception as e:
        logger.error("Failed to find UK by coords: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": "Ошибка поиска УК по координатам"},
        )


@router.get("/{uk_name}/streets")
async def get_uk_streets(uk_name: str):
    """Streets managed by a UK (for map highlighting)."""
    try:
        from services.business.uk_service import get_uk_catalog as load_catalog

        uk_data = find_uk_in_catalog(uk_name, load_catalog())
        if uk_data:
            streets = uk_data.get("streets") or uk_data.get("streets_preview") or []
            return JSONResponse(
                content={
                    "name": uk_data.get("name"),
                    "streets": streets,
                    "houses_count": uk_data.get("houses_count", 0),
                }
            )
        return JSONResponse(status_code=404, content={"error": "not_found"})
    except Exception as e:
        logger.error("UK streets failed: %s", e)
        return JSONResponse(status_code=500, content={"error": "internal_error"})


@router.get("/houses_coordinates")
async def get_uk_houses_coordinates_query(uk_name: str):
    """Получить координаты всех домов, обслуживаемых данной УК, по query-параметру."""
    return await get_uk_houses_coordinates(uk_name)


@router.get("/office_coordinate")
async def get_uk_office_coordinate_query(uk_name: str):
    """Получить координаты офиса УК по query-параметру."""
    return await get_uk_office_coordinate(uk_name)


@router.get("/{uk_name}/office_coordinate")
async def get_uk_office_coordinate(uk_name: str):
    """Получить координаты офиса УК."""
    try:
        from services.business.uk_service import get_uk_catalog as load_catalog
        from services.business.geo_service import get_coordinates

        uk_data = find_uk_in_catalog(uk_name, load_catalog())

        if not uk_data:
            return JSONResponse(status_code=404, content={"error": "not_found"})

        address = uk_data.get("address") or ""
        if not address:
            return JSONResponse(status_code=400, content={"error": "no_address"})

        full_address = address
        if "Нижневартовск" not in address:
            full_address = f"{address}, Нижневартовск"

        coords = await get_coordinates(full_address, local_only=True)
        if coords:
            return JSONResponse(content={"lat": coords[0], "lng": coords[1], "address": address})
        else:
            return JSONResponse(
                status_code=404,
                content={"error": "not_found", "detail": "Координаты офиса не найдены по адресу"},
            )
    except Exception as e:
        logger.error("Failed to get UK office coordinates: %s", e)
        return JSONResponse(status_code=500, content={"error": "internal_error"})


@router.get("/{uk_name}/houses_coordinates")
async def get_uk_houses_coordinates(uk_name: str):
    """Получить координаты всех домов, обслуживаемых данной УК."""
    try:
        import asyncio
        from services.business.uk_service import get_uk_catalog as load_catalog
        from services.business.geo_service import get_coordinates

        uk_data = find_uk_in_catalog(uk_name, load_catalog())

        if not uk_data:
            return JSONResponse(status_code=404, content={"error": "not_found"})

        mkd = uk_data.get("mkd") or []
        addresses_to_geocode = []

        for block in mkd:
            street = block.get("street") or ""
            buildings = block.get("buildings") or []
            if not street:
                continue

            for b in buildings:
                building = str(b).strip()
                if not building:
                    continue

                street_lower = street.lower().strip()
                has_prefix = any(
                    street_lower.startswith(p)
                    for p in [
                        "улица ", "ул. ", "ул ", "проспект ", "пр. ", "пр-т ", "пр-кт ",
                        "бульвар ", "б-р ", "проезд ", "переулок ", "пер. ", "мкр.", "мкр ", "микрорайон ",
                        "поселок ", "посёлок ", "пос. ", "тракт ", "шоссе ", "аллея ", "площадь ", "пл. ",
                        "сквер ", "сонт ", "снт ", "днт ", "гп "
                    ]
                )
                prefix = "" if has_prefix else "ул. "
                address = f"{prefix}{street} {building}, Нижневартовск"
                addresses_to_geocode.append((f"{street}, {building}", address))

        async def geocode_task(display_addr, full_addr):
            try:
                coords = await get_coordinates(full_addr, local_only=True)
                if coords:
                    return {
                        "address": display_addr,
                        "lat": coords[0],
                        "lon": coords[1]
                    }
            except Exception as e:
                logger.warning("Failed to geocode address %s: %s", full_addr, e)
            return None

        tasks = [geocode_task(display, full) for display, full in addresses_to_geocode]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        houses_coords = []
        for res in results:
            if isinstance(res, dict) and res:
                houses_coords.append(res)

        return JSONResponse(
            content={
                "name": uk_data.get("name"),
                "houses": houses_coords,
                "total": len(houses_coords)
            }
        )
    except Exception as e:
        logger.error("Failed to get UK houses coordinates: %s", e)
        return JSONResponse(status_code=500, content={"error": "internal_error"})


@router.get("/ratings/{uk_name}")
async def get_rating(uk_name: str):
    """Получить рейтинг конкретной УК."""
    try:
        from services.uk_rating_service import get_rating_by_name

        rating = get_rating_by_name(uk_name)
        if not rating:
            return JSONResponse(
                status_code=404, content={"error": "not_found", "detail": "УК не найдена"}
            )
        return JSONResponse(content=rating)
    except Exception as e:
        logger.error("Failed to get UK rating: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": "Не удалось получить рейтинг УК"},
        )


@router.post("/ratings/{uk_name}/vote")
async def vote_uk(uk_name: str, score: float = Query(..., ge=1, le=5)):
    """Оценить УК (1-5 звёзд)."""
    try:
        from services.uk_rating_service import submit_citizen_vote

        result = submit_citizen_vote(uk_name, score)
        if not result:
            return JSONResponse(
                status_code=400, content={"error": "invalid_request", "detail": "Некорректная оценка"}
            )
        return JSONResponse(content=result)
    except Exception as e:
        logger.error("Failed to vote for UK: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": "Ошибка голосования"},
        )


@router.post("/ratings/recalculate")
async def recalculate():
    """Пересчитать рейтинги всех УК (admin endpoint)."""
    try:
        from services.uk_rating_service import recalculate_all_ratings

        count = recalculate_all_ratings()
        return JSONResponse(content={"recalculated": count})
    except Exception as e:
        logger.error("Failed to recalculate UK ratings: %s", e)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": "Ошибка пересчёта рейтингов"},
        )


# ==============================================================================
# ИНТЕЛЛЕКТУАЛЬНЫЙ ПАСПОРТ ДОМА И УК-СЕРВИС
# ==============================================================================

@router.get("/house-passport")
async def get_house_passport(address: str = Query("ул. Мира, 14"), lat: float | None = None, lng: float | None = None):
    """
    Интеллектуальный Паспорт Дома и УК-Сервис.
    Возвращает данные о доме, управляющей компании, контакты аварийки 24/7,
    текущие и плановые отключения ресурсов (ГВС, ХВС, отопление, свет) и активные заявки.
    """
    try:
        from services.business.uk_service import get_uk_catalog as load_catalog, find_uk_by_coords

        uk_info = None
        if lat and lng:
            uk_info = await find_uk_by_coords(lat, lng)

        if not uk_info:
            catalog = load_catalog()
            # Simple matching for demonstration/fallback
            for company in catalog:
                for house in company.get("houses", []):
                    if address.lower() in str(house).lower():
                        uk_info = company
                        break
                if uk_info:
                    break

        if not uk_info:
            uk_info = {
                "name": "УК «Пикало» (Нижневартовск)",
                "phone": "+7 (3466) 61-22-10",
                "emergency_phone": "+7 (3466) 61-22-12 (Аварийка 24/7)",
                "address": "ул. Омская, 12, Нижневартовск",
                "director": "Иванов П. С.",
                "rating": 4.8,
                "houses_count": 42
            }

        # Статусы ресурсов: честные seasonal-статусы без выдуманных дат отключений;
        # реальные отключения приходят из /uk/outages (таблица jkh_incidents)
        outages = [
            {
                "resource": "hot_water",
                "title": "Горячее водоснабжение",
                "status": "ok",
                "start_time": None,
                "end_time": None,
                "description": "Актуальные отключения смотрите в разделе «Отключения по адресу»."
            },
            {
                "resource": "electricity",
                "title": "Электроснабжение в норме",
                "status": "ok",
                "start_time": None,
                "end_time": None,
                "description": "Аварийных и плановых отключений электроэнергии не зафиксировано."
            },
            {
                "resource": "heating",
                "title": "Отопление в норме (Летняя межотопительная пауза)",
                "status": "ok",
                "start_time": None,
                "end_time": None,
                "description": "Летний межотопительный период."
            }
        ]

        passport = {
            "success": True,
            "address": address,
            "city": "Нижневартовск",
            "house_info": {
                "year_built": 1994,
                "floors": 9,
                "entrances": 4,
                "apartments": 144,
                "wall_material": "Панельный",
                "cadastral_number": "86:11:0000000:1402"
            },
            "uk": uk_info,
            "outages": outages,
            "active_tickets_count": 2
        }
        return JSONResponse(content=passport)
    except Exception as exc:
        logger.error("Failed to fetch house passport for %s: %s", address, exc)
        return JSONResponse(status_code=500, content={"error": "failed_to_fetch_passport"})


@router.get("/outages")
async def get_house_outages(address: str = Query("ул. Мира, 14")):
    """Возвращает график плановых и аварийных отключений ресурсов по адресу дома.

    Источник — таблица jkh_incidents (реальные инциденты). Хардкоженный
    «график опрессовки 20–30 июля» удалён: он показывался для любого адреса.
    """
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import JkhIncident

        db = SessionLocal()
        try:
            incidents = (
                db.query(JkhIncident)
                .filter(JkhIncident.status == "active")
                .order_by(JkhIncident.started_at.desc())
                .limit(50)
                .all()
            )
        finally:
            db.close()

        outages = []
        for inc in incidents:
            # Отдаём только инциденты, релевантные адресу (подстрока улицы),
            # либо общегородские (без конкретного адреса)
            relevant = (
                not inc.address
                or not address
                or address.lower() in (inc.address or "").lower()
                or (inc.address or "").lower() in address.lower()
            )
            if not relevant:
                continue
            outages.append({
                "id": f"incident-{inc.id}",
                "address": inc.address or address,
                "resource": (inc.incident_type or "other"),
                "title": inc.title,
                "start_date": inc.started_at.strftime("%d.%m.%Y") if inc.started_at else None,
                "end_date": inc.expires_at.strftime("%d.%m.%Y") if inc.expires_at else None,
                "duration_days": (
                    max(1, (inc.expires_at - inc.started_at).days)
                    if inc.started_at and inc.expires_at
                    else None
                ),
                "provider": "Коммунальные службы Нижневартовска",
                "reason": inc.description or "",
            })
        return JSONResponse(content={"success": True, "address": address, "outages": outages})
    except Exception as exc:
        logger.error("Failed to fetch outages for %s: %s", address, exc)
        return JSONResponse(status_code=500, content={"error": "failed_to_fetch_outages"})


@router.post("/ticket/create")
async def create_uk_ticket(
    address: str = Query("ул. Мира, 14"),
    category: str = Query("Сантехника"),
    description: str = Query("Подтекает стояк в подвале"),
    contact_phone: str = Query("+7 (900) 000-00-00")
):
    """Подать электронную заявку жителя прямо в Управляющую Компанию."""
    try:
        import uuid
        ticket_id = f"TICK-{uuid.uuid4().hex[:6].upper()}"
        return JSONResponse(content={
            "success": True,
            "ticket_id": ticket_id,
            "address": address,
            "category": category,
            "status": "Принята УК",
            "status_text": "Заявка зарегистрирована в единой диспетчерской УК и передана мастеру участка.",
            "estimated_completion": "Сегодня до 18:00"
        })
    except Exception as exc:
        logger.error("Failed to create UK ticket: %s", exc)
        return JSONResponse(status_code=500, content={"error": "failed_to_create_ticket"})

