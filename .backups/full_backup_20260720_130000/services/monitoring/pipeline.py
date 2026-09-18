"""Core complaint processing pipeline and address validation."""

import logging
import re
from datetime import datetime

from .dedup import save_to_db
from .publisher import publish_to_telegram

logger = logging.getLogger(__name__)


# Global stats dict
stats = {
    "tg_total": 0,
    "tg_published": 0,
    "tg_filtered": 0,
    "vk_total": 0,
    "vk_published": 0,
    "vk_filtered": 0,
    "by_category": {},
}


def _has_concrete_address(address: str | None) -> bool:
    """Check if address contains a VALID street name + house number.

    СТРОГИЕ ПРАВИЛА:
    - Должен быть маркер улицы (ул., улица, пр., проспект и т.д.) ИЛИ известная улица Нижневартовска
    - Должен быть номер дома (1-3 цифры, возможно с буквой)
    - Адрес должен содержать минимум 2 слова (улица + номер считаются)
    - Отклоняем адреса без маркера улицы, если это не известная улица города
    """
    if not address:
        return False

    cleaned = address.strip().rstrip(",")
    if not cleaned:
        return False

    # 1. Маркер улицы/проспекта/переулка и т.д.
    has_street = bool(
        re.search(
            r"(?:ул\.?|улица|пр\.?|проспект|пер\.?|переулок|б-р|бульвар|мкр\.?|микрорайон|наб\.?|набережная)",
            cleaned,
            re.IGNORECASE,
        )
    )

    # 2. Известные улицы Нижневартовска (без маркера тоже принимаем)
    has_known_street = any(
        hint in cleaned.lower()
        for hint in (
            "мира",
            "ленина",
            "пионерская",
            "омская",
            "чапаева",
            "интернациональная",
            "нефтяников",
            "дружбы народов",
            "северная",
            "маршала жукова",
            "спортивная",
            "таежная",
            "мусы джалиля",
            "ханты-мансийская",
            "60 лет октября",
            "индустриальная",
            "рабочая",
            "кузоваткина",
            "авиаторов",
        )
    )

    # 3. Номер дома: 1-3 цифры, опционально с буквой (1а, 15б, 120)
    has_house = bool(
        re.search(r"(?:^|[\s,])\d{1,3}[а-яА-Яa-zA-Z]?(?:[\s,/]|$)", cleaned)
    )

    # 4. Минимальная длина: адрес должен содержать хотя бы улицу + номер
    words = [w for w in cleaned.split() if len(w) > 1]
    has_min_length = len(words) >= 2

    # СТРОГО: требуем И маркер улицы (или известную улицу), И номер дома, И минимальную длину
    if not has_house:
        return False
    if not has_min_length:
        return False
    if not (has_street or has_known_street):
        return False

    # Отклоняем подозрительные адреса
    lower = cleaned.lower()
    suspicious_patterns = [
        "где-то",
        "где то",
        "примерно",
        "около",
        "возле",
        "рядом",
        "недалеко от",
        "напротив",
        "за",
        "у",
        "рядом с",
    ]
    # Если адрес состоит ТОЛЬКО из подозрительных слов без конкретной улицы — отклоняем
    if not has_street and not has_known_street:
        return False

    return True


def _has_lost_found_location(address: str | None, text: str) -> bool:
    """Checks if lost & found complaint specifies a location (street, district, landmark, etc.)"""
    if address:
        cleaned = address.lower()
        if any(h in cleaned for h in ("ул", "улица", "мкр", "микрорайон", "район", "квартал", "пр", "проспект", "пер", "переулок", "бульвар", "наб")):
            return True
        known_streets = ("мира", "ленина", "пионерская", "омская", "чапаева", "интернациональная", "нефтяников", "дружбы народов", "северная", "маршала жукова", "спортивная", "таежная", "мусы джалиля", "ханты-мансийская", "60 лет октября", "индустриальная", "рабочая", "кузоваткина", "авиаторов")
        if any(s in cleaned for s in known_streets):
            return True
            
    text_lower = (text or "").lower()
    keywords = ("ул.", "улица", "улице", "улиц", "мкр", "микрорайон", "микрорайоне", "район", "районе", "району", "квартал", "квартале", "проспект", "бульвар", "набережная", "парк", "сквер", "тц", "рынок", "около", "возле", "рядом с", "остановка")
    if any(kw in text_lower for kw in keywords):
        return True
        
    return False


async def process_complaint(
    client,
    text,
    category,
    address,
    summary,
    provider,
    source,
    source_label,
    source_link,
    msg_id=None,
    channel=None,
    location_hints=None,
    exif_lat=None,
    exif_lon=None,
    title=None,
    created_at=None,
):
    """Unified complaint pipeline with deduplicated marker creation."""
    lat, lon = None, None
    if exif_lat and exif_lon:
        lat, lon = exif_lat, exif_lon
        if not address:
            try:
                from services.geo_service import reverse_geocode

                rev_addr = await reverse_geocode(exif_lat, exif_lon)
                if rev_addr:
                    address = rev_addr
            except Exception:
                pass
    else:
        from services.geo_service import geoparse

        geo = await geoparse(text, ai_address=address, location_hints=location_hints)
        lat = geo.get("lat")
        lon = geo.get("lng")
        if geo.get("address"):
            address = geo["address"]

    # Координаты есть, но адрес не прошёл валидацию — reverse geocode по GPS/EXIF
    if not _has_concrete_address(address) and lat is not None and lon is not None:
        try:
            from services.geo_service import reverse_geocode, sanitize_address_candidate

            rev = await reverse_geocode(lat, lon)
            if rev:
                candidate = sanitize_address_candidate(rev) or rev
                if _has_concrete_address(candidate):
                    address = candidate
        except Exception:
            pass

    from services.zai_service import build_marker_summary

    marker_summary = title or build_marker_summary(summary, text, max_len=120)

    from services.geo_service import (
        is_coords_in_city,
        is_street_level_address,
        resolve_address_from_coords,
    )

    is_lost_found = category in ("Животные", "Вещи")
    if is_lost_found:
        t = text.lower()
        lost_words = ["пропал", "потерян", "потерял", "утерян", "убежал", "ищем", "разыскива", "помогите найти"]
        found_words = ["найден", "нашли", "нашел", "нашла", "прибился", "прибил", "замечен", "лежит", "сидит", "бегает"]

        is_lost = False
        for lw in lost_words:
            if lw in t:
                has_found = any(fw in t for fw in found_words)
                if not has_found:
                    is_lost = True
                    break
                else:
                    if "пропал" in t or "потерял" in t or "ищем" in t:
                        is_lost = True
                        break

        # Map to specific subcategories for the lost & found page
        if not is_lost:
            if category == "Животные":
                category = "Найдено животное"
            elif category == "Вещи":
                category = "Найдена вещь"

        if not _has_lost_found_location(address, text):
            logger.info(
                "⏭️ Lost/Found без указания адреса или района — пропуск: %s | %s",
                category,
                source_label,
            )
            stats["by_category"][category] = stats["by_category"].get(category, 0) + 1
            return False

    if lat is not None and lon is not None:
        if not is_coords_in_city(float(lat), float(lon)):
            logger.info(
                "⏭️ Координаты вне города — пропуск: %s @ %s",
                category,
                source_label,
            )
            stats["by_category"][category] = stats["by_category"].get(category, 0) + 1
            return False
        address = await resolve_address_from_coords(
            float(lat),
            float(lon),
            existing=address,
        )
    elif not _has_concrete_address(address):
        if not is_lost_found:
            logger.info(
                "⏭️ Нет адреса и координат — пропуск: %s | addr=%s | %s",
                category,
                address,
                source_label,
            )
            stats["by_category"][category] = stats["by_category"].get(category, 0) + 1
            return False

    if not is_lost_found and not _has_concrete_address(address) and not is_street_level_address(address):
        logger.info(
            "⏭️ Адрес не распознан — пропуск: %s | addr=%s | %s",
            category,
            address,
            source_label,
        )
        stats["by_category"][category] = stats["by_category"].get(category, 0) + 1
        return False

    report_id, is_new_report = await save_to_db(
        marker_summary,
        text,
        lat,
        lon,
        address,
        category,
        source,
        msg_id,
        channel,
        description=summary,
        created_at=created_at,
    )

    geo_accuracy = None
    if lat and lon:
        if exif_lat and exif_lon and _has_concrete_address(address) or _has_concrete_address(address) and address and len(address.split()) >= 3:
            geo_accuracy = "high"
        else:
            geo_accuracy = "medium"
    elif _has_concrete_address(address):
        # Координат нет, но адрес конкретный — всё равно high
        geo_accuracy = "high"

    timestamp = datetime.now().strftime("%d.%m.%Y %H:%M")
    published = False

    if is_new_report and report_id:
        try:
            from services.push_notification_service import trigger_push_for_report
            await trigger_push_for_report(report_id, client=client)
            published = True
        except Exception as push_err:
            logger.error("Failed to trigger push for report #%d: %s", report_id, push_err)

    stats["by_category"][category] = stats["by_category"].get(category, 0) + 1
    return published
