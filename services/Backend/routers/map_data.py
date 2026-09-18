"""Map feed endpoints: public reports, geocoded markers, and city events."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urljoin

import httpx
from bs4 import BeautifulSoup
from fastapi import APIRouter, Query

from services.ai.zai_service import build_marker_summary, make_marker_summary
from services.business.category_service import normalize_category
from services.data_layer.database import SessionLocal
from services.data_layer.models import Report
from services.geo_service import CITY_NAME, geoparse, sanitize_address_candidate

router = APIRouter(tags=["map-data"])
logger = logging.getLogger(__name__)

_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_EVENTS_VENUES_FILE = _PROJECT_ROOT / "data" / "events_venues.json"
_events_venues_cache: dict[str, dict[str, Any]] | None = None

_SCRAPED_CACHE_FILE = _PROJECT_ROOT / "data" / "scraped_events_cache.json"


def _save_scraped_events_cache(afisha: list[dict], gorodzovet: list[dict]) -> None:
    try:
        _SCRAPED_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "afisha": afisha,
            "gorodzovet": gorodzovet,
            "updated_at": datetime.now().isoformat()
        }
        _SCRAPED_CACHE_FILE.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:
        logger.warning("Failed to save scraped events cache file: %s", e)


def _load_scraped_events_cache() -> tuple[list[dict], list[dict]]:
    if not _SCRAPED_CACHE_FILE.is_file():
        return [], []
    try:
        payload = json.loads(_SCRAPED_CACHE_FILE.read_text(encoding="utf-8"))
        return payload.get("afisha") or [], payload.get("gorodzovet") or []
    except Exception as e:
        logger.warning("Failed to load scraped events cache file: %s", e)
        return [], []


AFISHA_URL = "https://www.n-vartovsk.ru/afisha/"
CITY_EVENT_LOOKAHEAD_DAYS = int(os.getenv("CITY_EVENT_LOOKAHEAD_DAYS", "30"))

VENUE_COORDS: dict[str, dict[str, Any]] = {
    "дворец искусств": {
        "name": "Дворец искусств",
        "lat": 60.9404877,
        "lng": 76.5587701,
        "address": "ул. Ленина, 7, Нижневартовск",
    },
    "площади дворца искусств": {
        "name": "Площадь Дворца искусств",
        "lat": 60.9404877,
        "lng": 76.5587701,
        "address": "ул. Ленина, 7, Нижневартовск",
    },
    "площадь нефтяников": {
        "name": "Площадь Нефтяников",
        "lat": 60.9368,
        "lng": 76.5645,
        "address": "Площадь Нефтяников, Нижневартовск",
    },
    "green park": {
        "name": "МФК Green Park",
        "lat": 60.9384798,
        "lng": 76.5558084,
        "address": "ул. Ленина, 8, Нижневартовск",
    },
    "грин парк": {
        "name": "МФК Green Park",
        "lat": 60.9384798,
        "lng": 76.5558084,
        "address": "ул. Ленина, 8, Нижневартовск",
    },
    "ленина, 8": {
        "name": "МФК Green Park",
        "lat": 60.9384798,
        "lng": 76.5558084,
        "address": "ул. Ленина, 8, Нижневартовск",
    },
    "дворец культуры октябрь": {
        "name": "Дворец культуры «Октябрь»",
        "lat": 60.9298,
        "lng": 76.5492,
        "address": "ул. 60 лет Октября, 11/2, Нижневартовск",
    },
    "дк октябрь": {
        "name": "Дворец культуры «Октябрь»",
        "lat": 60.9298,
        "lng": 76.5492,
        "address": "ул. 60 лет Октября, 11/2, Нижневартовск",
    },
    "дворец культуры «октябрь»": {
        "name": "Дворец культуры «Октябрь»",
        "lat": 60.9298,
        "lng": 76.5492,
        "address": "ул. 60 лет Октября, 11/2, Нижневартовск",
    },
    "югра молл": {
        "name": "ТРК «Югра Молл»",
        "lat": 60.9422,
        "lng": 76.5710,
        "address": "ул. Ленина, 15п, Нижневартовск",
    },
    "трк югра молл": {
        "name": "ТРК «Югра Молл»",
        "lat": 60.9422,
        "lng": 76.5710,
        "address": "ул. Ленина, 15п, Нижневартовск",
    },
    "сити центр": {
        "name": "ТЦ «Сити-Центр»",
        "lat": 60.9380,
        "lng": 76.5530,
        "address": "ул. Ленина, 8а, Нижневартовск",
    },
    "ледовый дворец": {
        "name": "Ледовый дворец спорта",
        "lat": 60.9272,
        "lng": 76.5415,
        "address": "ул. 60 лет Октября, 12б, Нижневартовск",
    },
    "парк победы": {
        "name": "Парк Победы",
        "lat": 60.9400,
        "lng": 76.5480,
        "address": "Парк Победы, Нижневартовск",
    },
    "комсомольское озеро": {
        "name": "Комсомольское озеро",
        "lat": 60.9450,
        "lng": 76.5500,
        "address": "Комсомольское озеро, Нижневартовск",
    },
    "набережная": {
        "name": "Набережная р. Обь",
        "lat": 60.9300,
        "lng": 76.5500,
        "address": "ул. Пикмана, Набережная, Нижневартовск",
    },
    "краеведческий музей": {
        "name": "Нижневартовский краеведческий музей",
        "lat": 60.9398,
        "lng": 76.5615,
        "address": "ул. Ленина, 9/1, Нижневартовск",
    },
    "центральная библиотека": {
        "name": "Центральная городская библиотека им. М.К. Анисимковой",
        "lat": 60.9431,
        "lng": 76.5772,
        "address": "ул. Дружбы Народов, 22, Нижневартовск",
    },
    "администрация": {
        "name": "Администрация города Нижневартовска",
        "lat": 60.9372,
        "lng": 76.5531,
        "address": "ул. Таежная, 24, Нижневартовск",
    },
    "стадион нефтяник": {
        "name": "Центральный стадион",
        "lat": 60.9255,
        "lng": 76.5360,
        "address": "ул. 60 лет Октября, 20/1, Нижневартовск",
    },
    "центральный стадион": {
        "name": "Центральный стадион",
        "lat": 60.9255,
        "lng": 76.5360,
        "address": "ул. 60 лет Октября, 20/1, Нижневартовск",
    },
}

EVENT_DATE_RE = re.compile(
    r"(?P<date>\d{2}\.\d{2}\.\d{4})(?:\s+(?P<time>\d{2}:\d{2}))?"
)
MAP_REPORTS_TIMEOUT_SECONDS = 12.0
MAP_EVENTS_TIMEOUT_SECONDS = 12.0
MAP_FEED_ENABLE_GEOPARSE = (os.getenv("MAP_FEED_ENABLE_GEOPARSE") or "0").strip() != "0"
MAP_PER_REPORT_TIMEOUT_SECONDS = float(
    os.getenv("MAP_PER_REPORT_TIMEOUT_SECONDS", "2.5")
)
MAP_REPORT_MAX_AGE_DAYS = int(os.getenv("MAP_REPORT_MAX_AGE_DAYS", "120"))
MAP_EVENTS_CACHE_TTL_SECONDS = int(os.getenv("MAP_EVENTS_CACHE_TTL_SECONDS", "900"))
MAP_FEED_CACHE_TTL_SECONDS = int(os.getenv("MAP_FEED_CACHE_TTL_SECONDS", "20"))
_events_cache: dict[str, Any] = {
    "date": None,
    "expires_at": None,
    "payload": None,
}
_events_cache_lock = asyncio.Lock()
_feed_cache: dict[str, Any] = {"key": None, "expires_at": None, "payload": None}
_feed_cache_lock = asyncio.Lock()

CITY_PROBLEM_CATEGORIES = {
    "ЧП",
    "ЖКХ",
    "Дороги",
    "Освещение",
    "Транспорт",
    "Экология",
    "Безопасность",
    "Снег/Наледь",
    "Медицина",
    "Образование",
    "Парковки",
    "Строительство",
    "Животные",
    "Вещи",
    "Мероприятие",
    "Прочее",
}


CITY_PROBLEM_KEYWORDS = (
    "авар",
    "яма",
    "дорог",
    "тротуар",
    "двор",
    "подъезд",
    "крыша",
    "лифт",
    "свет",
    "освещ",
    "отключ",
    "порыв",
    "прорыв",
    "утеч",
    "канализ",
    "мусор",
    "свалк",
    "парк",
    "сквер",
    "парковк",
    "снег",
    "налед",
    "лед",
    "дым",
    "вон",
    "запах",
    "шум",
    "пожар",
    "опасн",
    "светофор",
    "дтп",
    "ремонт",
    "строитель",
    "эколог",
)

TG_EVENT_KEYWORDS = (
    "концерт",
    "спектак",
    "фестиваль",
    "выставк",
    "мероприят",
    "мастер-класс",
    "лекци",
    "кино",
    "турнир",
    "ярмарк",
    "фест",
    "шоу",
    "встреч",
    "праздник",
    "открытие",
)

NON_CITY_PROBLEM_KEYWORDS = (
    "мероприят",
    "афиша",
    "концерт",
    "спектак",
    "фестиваль",
    "мастер-класс",
    "лекци",
    "приглаша",
    "скидк",
    "акци",
    "розыгрыш",
    "ваканси",
    "продам",
    "сдам",
    "аренда",
    "реклама",
)


def _now_local() -> datetime:
    return datetime.now()


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _report_text(report: dict[str, Any]) -> str:
    return " ".join(
        str(report.get(field) or "").strip().lower()
        for field in ("title", "summary", "description", "address", "category")
    )


def _normalize_report_address(report: dict[str, Any]) -> str | None:
    raw = report.get("address")
    if isinstance(raw, str) and raw.strip().upper().startswith("GPS "):
        cleaned = raw.strip()
        report["address"] = cleaned
        return cleaned
    normalized = sanitize_address_candidate(report.get("address"))
    if normalized:
        report["address"] = normalized
    return normalized


def _marker_text_signature(value: Any) -> str:
    cleaned = make_marker_summary(str(value or ""), max_len=120).lower()
    cleaned = re.sub(r"[^a-zа-яё0-9\s]", " ", cleaned, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", cleaned).strip()


def _marker_coords_bucket(lat: Any, lng: Any) -> tuple[float, float] | None:
    if lat is None or lng is None:
        return None
    try:
        return (round(float(lat), 3), round(float(lng), 3))
    except (TypeError, ValueError):
        return None


def _dedupe_marker_records(markers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    unique: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()

    for marker in markers:
        category = _normalize_category(marker.get("category"))
        address = sanitize_address_candidate(marker.get("address"))
        summary = _marker_text_signature(
            marker.get("summary") or marker.get("description")
        )
        coords = _marker_coords_bucket(marker.get("lat"), marker.get("lng"))

        candidate_keys: list[tuple[Any, ...]] = []
        # Primary: address + category alone is enough to be a duplicate
        if address:
            candidate_keys.append(("addr_cat", category, address))
        # Secondary: same coords bucket + category
        if coords:
            candidate_keys.append(("coords_cat", category, coords))
        # Tertiary: address + summary for text-level dedup
        if address and summary:
            candidate_keys.append(("full", category, address, summary))
        if coords and summary:
            candidate_keys.append(("full_coords", category, coords, summary))

        if candidate_keys and any(key in seen for key in candidate_keys):
            continue

        unique.append(marker)
        for key in candidate_keys:
            seen.add(key)

    return unique


def _is_recent_report(report: dict[str, Any]) -> bool:
    raw = report.get("created_at") or report.get("updated_at")
    parsed = _parse_dt(raw if isinstance(raw, str) else None)
    if parsed is None:
        return True
    if parsed.tzinfo is not None:
        parsed = parsed.replace(tzinfo=None)
    return parsed >= _now_local() - timedelta(days=MAP_REPORT_MAX_AGE_DAYS)


def _is_city_problem(report: dict[str, Any]) -> bool:
    source = str(report.get("source") or "").strip().lower()
    category = _normalize_category(report.get("category"))
    text = _report_text(report)

    if category == "Мероприятие" and _is_public_source(source):
        return True
    if source == "official:afisha" or category == "Мероприятие":
        return False
    if any(keyword in text for keyword in NON_CITY_PROBLEM_KEYWORDS):
        return False
    if category in CITY_PROBLEM_CATEGORIES:
        return True
    raw_category = str(report.get("category") or "").strip().lower()
    if any(
        hint in raw_category
        for hint in (
            "дорог",
            "тротуар",
            "жкх",
            "двор",
            "освещ",
            "транспорт",
            "эколог",
            "безопас",
            "снег",
            "налед",
            "медиц",
            "образован",
            "благоустрой",
            "животн",
            "торгов",
        )
    ):
        return True
    return any(keyword in text for keyword in CITY_PROBLEM_KEYWORDS)


def _cleanup_reason(report: dict[str, Any]) -> str | None:
    if not _is_recent_report(report):
        return "stale"
    if not _is_city_problem(report):
        return "not_city_problem"
    if _normalize_report_address(report) is None:
        lat = report.get("lat")
        lng = report.get("lng")
        if lat is not None and lng is not None:
            from services.geo_service import format_gps_fallback_address

            report["address"] = format_gps_fallback_address(float(lat), float(lng))
            return None
        return "invalid_address"
    return None


def _normalize_category(value: Any) -> str:
    return normalize_category(value)


def _is_event_category(category: Any) -> bool:
    return _normalize_category(category) == "Мероприятие"


def _address_confidence(report: dict[str, Any], lat: Any, lng: Any) -> str:
    if lat is None or lng is None:
        return "none"
    if _normalize_report_address(report) is not None:
        return "high"
    return "medium"


def _parse_bbox(value: str | None) -> tuple[float, float, float, float] | None:
    if not value:
        return None
    try:
        parts = [float(item.strip()) for item in value.split(",")]
    except ValueError:
        return None
    if len(parts) != 4:
        return None
    min_lng, min_lat, max_lng, max_lat = parts
    if min_lat > max_lat:
        min_lat, max_lat = max_lat, min_lat
    if min_lng > max_lng:
        min_lng, max_lng = max_lng, min_lng
    return min_lng, min_lat, max_lng, max_lat


def _filter_bbox(
    markers: list[dict[str, Any]], bbox: tuple[float, float, float, float] | None
) -> list[dict[str, Any]]:
    if bbox is None:
        return markers
    min_lng, min_lat, max_lng, max_lat = bbox
    return [
        marker
        for marker in markers
        if marker.get("lat") is not None
        and marker.get("lng") is not None
        and min_lat <= float(marker["lat"]) <= max_lat
        and min_lng <= float(marker["lng"]) <= max_lng
    ]


def _filter_layers(markers: list[dict[str, Any]], layers: set[str]) -> list[dict[str, Any]]:
    if not layers or "all" in layers:
        return markers
    filtered: list[dict[str, Any]] = []
    for marker in markers:
        source_kind = str(marker.get("source_kind") or "").lower()
        is_event = source_kind == "event" or _is_event_category(marker.get("category"))
        if is_event and "events" in layers or not is_event and "problems" in layers:
            filtered.append(marker)
    return filtered


def _source_label(source: str) -> str:
    lower = (source or "").lower()
    if lower.startswith("vk:"):
        return f"VK · {source.split(':', 1)[1]}"
    if lower.startswith("tg:") or lower.startswith("telegram:"):
        return f"Telegram · {source.split(':', 1)[1]}"
    return source or "Источник не указан"


def _is_public_source(source: str) -> bool:
    lower = (source or "").lower()
    return (
        lower.startswith("vk:")
        or lower.startswith("tg:")
        or lower.startswith("telegram:")
    )


def _load_events_venues() -> dict[str, dict[str, Any]]:
    global _events_venues_cache
    if _events_venues_cache is not None:
        return _events_venues_cache

    merged = {key.lower(): value for key, value in VENUE_COORDS.items()}
    if _EVENTS_VENUES_FILE.exists():
        try:
            payload = json.loads(_EVENTS_VENUES_FILE.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                for key, value in payload.items():
                    if isinstance(value, dict) and value.get("lat") and value.get("lng"):
                        merged[str(key).lower()] = value
        except Exception:
            pass

    _events_venues_cache = merged
    return merged


_EVENT_VENUE_SKIP_TERMS = (
    "самотлорские ночи",
    "фестиваль искусств",
    "фестиваля искусств",
)


def _venue_key_matches(key: str, haystack: str) -> bool:
    if key in _EVENT_VENUE_SKIP_TERMS:
        return False
    if len(key) < 6:
        return (
            re.search(
                rf"(?:^|[\s,.«»(]){re.escape(key)}(?:[\s,.»)]|$)",
                haystack,
            )
            is not None
        )
    return key in haystack


def _match_known_venue(text: str) -> dict[str, Any] | None:
    haystack = text.lower()
    for skip in _EVENT_VENUE_SKIP_TERMS:
        if skip in haystack and "на " not in haystack and "ул." not in haystack:
            # Festival title without explicit place — avoid fuzzy venue hits.
            pass
    venues = _load_events_venues()
    for key in sorted(venues.keys(), key=len, reverse=True):
        if _venue_key_matches(key, haystack):
            return dict(venues[key])
    return None


def _extract_event_place_phrases(text: str) -> list[str]:
    haystack = re.sub(r"\s+", " ", text).strip()
    if not haystack:
        return []

    patterns = (
        r"(?:^|[\s,.])на\s+(?:площад[еи]|стадион[еу]|набережн[оеой]|катке|сцене|базе|территории|площадке)\s+([^,.]+)",
        r"(?:ул\.|улица)\s+[А-Яа-яЁё0-9\-\s]+?(?:\s+\d+)?",
        r"площад[ьи]\s+[^,.]+",
        r"дворец\s+искусств[^,.]*",
        r"краеведческ\w*\s+музе\w*",
        r"центральн\w*\s+стадион\w*",
        r"набережн\w*",
    )
    found: list[str] = []
    seen: set[str] = set()
    for pattern in patterns:
        for match in re.finditer(pattern, haystack, flags=re.IGNORECASE):
            phrase = match.group(1).strip() if match.lastindex else match.group(0).strip()
            phrase = phrase.strip(" -–—")
            if len(phrase) < 4:
                continue
            key = phrase.lower()
            if key in seen:
                continue
            seen.add(key)
            found.append(phrase)
    return found


def _event_geo_is_reliable(address: str, source_text: str) -> bool:
    addr = (address or "").lower()
    text = (source_text or "").lower()
    if "самотлор" in addr:
        return any(
            token in text
            for token in (
                "стадион",
                "центральн",
                "спортивн",
                "на ул",
                "улица",
                "дворец",
                "набережн",
                "музей",
                "площад",
            )
        )
    return bool(addr)


async def _resolve_event_venue(*, text: str, place_hint: str = "") -> dict[str, Any] | None:
    """Resolve event coordinates from explicit venue/address only (no city-wide fallbacks)."""
    parts = [part.strip() for part in (text, place_hint) if part and part.strip()]
    combined = " ".join(parts)
    if not combined:
        return None

    known = _match_known_venue(combined)
    if known:
        return known

    if not MAP_FEED_ENABLE_GEOPARSE:
        return None

    candidates = []
    if place_hint and place_hint.strip().lower() not in {CITY_NAME.lower(), "нижневартовск"}:
        candidates.append(place_hint.strip())
    candidates.extend(_extract_event_place_phrases(combined))

    seen: set[str] = set()
    for candidate in candidates:
        key = candidate.lower()
        if key in seen:
            continue
        seen.add(key)

        try:
            geo = await asyncio.wait_for(
                geoparse(combined, location_hints=candidate),
                timeout=4.5,
            )
        except Exception:
            continue

        lat = geo.get("lat")
        lng = geo.get("lng")
        if lat is None or lng is None:
            continue

        address = (geo.get("address") or candidate).strip()
        if not _event_geo_is_reliable(address, combined):
            continue

        return {
            "name": candidate[:120],
            "lat": float(lat),
            "lng": float(lng),
            "address": address,
        }

    return None


def _extract_event_title(text: str) -> str:
    cleaned = EVENT_DATE_RE.sub("", text, count=1).strip(" -")
    first_sentence = re.split(r"(?<=[.!?])\s+", cleaned, maxsplit=1)[0].strip()
    return (first_sentence or cleaned)[:180]


def _parse_time_str_to_24h(time_str: str) -> tuple[int, int]:
    """Parse time string which might be in 12-hour format (e.g. 2:00 PM, 2:00 дня, 2:00)
    and return (hour, minute) in 24-hour format."""
    time_str = time_str.strip().lower()
    is_pm = False
    is_am = False
    if "pm" in time_str or "веч" in time_str or "дня" in time_str or "пп" in time_str:
        is_pm = True
    elif "am" in time_str or "утр" in time_str or "ноч" in time_str or "дп" in time_str:
        is_am = True

    digits_match = re.search(r"(\d{1,2}):(\d{2})", time_str)
    if not digits_match:
        return 12, 0

    hour = int(digits_match.group(1))
    minute = int(digits_match.group(2))

    if is_pm:
        if hour < 12:
            hour += 12
    elif is_am:
        if hour == 12:
            hour = 0
    else:
        if 1 <= hour <= 8:
            hour += 12

    return hour, minute


def _titles_are_similar(t1: str, t2: str) -> bool:
    t1_clean = re.sub(r"[^a-zа-яё0-9]", " ", t1.lower())
    t2_clean = re.sub(r"[^a-zа-яё0-9]", " ", t2.lower())
    words1 = set(w for w in t1_clean.split() if len(w) > 2)
    words2 = set(w for w in t2_clean.split() if len(w) > 2)
    if not words1 or not words2:
        return t1_clean == t2_clean
    intersection = words1.intersection(words2)
    union = words1.union(words2)
    jaccard = len(intersection) / len(union)
    return jaccard > 0.45 or (len(intersection) >= 2 and (intersection.issubset(words1) or intersection.issubset(words2)))


def _extract_event_datetime(text: str) -> datetime | None:
    # 1. Try standard dd.mm.yyyy followed by time
    date_match = re.search(r"\b(?P<day>\d{1,2})\.(?P<month>\d{1,2})\.(?P<year>\d{4})\b", text)
    if date_match:
        day_val = int(date_match.group("day"))
        month_val = int(date_match.group("month"))
        year_val = int(date_match.group("year"))
        remaining_text = text[date_match.end():].strip()
        time_match = re.search(r"\b(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<indicator>am|pm|веч|дня|утра|ночи|дп|пп)?\b", remaining_text, re.IGNORECASE)
        if not time_match:
            time_match = re.search(r"\b(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<indicator>am|pm|веч|дня|утра|ночи|дп|пп)?\b", text, re.IGNORECASE)

        if time_match:
            hour_val, minute_val = _parse_time_str_to_24h(time_match.group(0))
        else:
            hour_val, minute_val = 12, 0
        try:
            return datetime(year_val, month_val, day_val, hour_val, minute_val)
        except ValueError:
            pass

    # 2. Try dd.mm without year
    date_no_year_match = re.search(r"\b(?P<day>\d{1,2})\.(?P<month>\d{1,2})\b", text)
    if date_no_year_match:
        is_full_date = False
        start = date_no_year_match.start()
        if start >= 5 and text[start-1] == '.' and text[start-5:start-1].isdigit():
            is_full_date = True
        end = date_no_year_match.end()
        if end < len(text) - 4 and text[end] == '.' and text[end+1:end+5].isdigit():
            is_full_date = True

        if not is_full_date:
            day_val = int(date_no_year_match.group("day"))
            month_val = int(date_no_year_match.group("month"))
            remaining_text = text[date_no_year_match.end():].strip()
            time_match = re.search(r"\b(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<indicator>am|pm|веч|дня|утра|ночи|дп|пп)?\b", remaining_text, re.IGNORECASE)
            if not time_match:
                time_match = re.search(r"\b(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<indicator>am|pm|веч|дня|утра|ночи|дп|пп)?\b", text, re.IGNORECASE)

            if time_match:
                hour_val, minute_val = _parse_time_str_to_24h(time_match.group(0))
            else:
                hour_val, minute_val = 12, 0

            today = _now_local().date()
            year_val = today.year
            if month_val < today.month:
                year_val += 1
            try:
                return datetime(year_val, month_val, day_val, hour_val, minute_val)
            except ValueError:
                pass

    # 3. Try dd Month format (e.g. "12 июня", "12 июня 18:00")
    ru_months = {
        "янв": 1, "фев": 2, "мар": 3, "апр": 4, "май": 5, "июн": 6,
        "июл": 7, "авг": 8, "сен": 9, "окт": 10, "ноя": 11, "дек": 12
    }
    match_words = re.search(
        r"\b(?P<day>\d{1,2})\s+(?P<month>[а-яёА-ЯЁ]{3,8})\b",
        text,
        re.IGNORECASE
    )
    if match_words:
        day_val = int(match_words.group("day"))
        month_name = match_words.group("month")[:3].lower()
        month_val = ru_months.get(month_name)
        if month_val:
            remaining_text = text[match_words.end():].strip()
            time_match = re.search(r"\b(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<indicator>am|pm|веч|дня|утра|ночи|дп|пп)?\b", remaining_text, re.IGNORECASE)
            if not time_match:
                time_match = re.search(r"\b(?P<hour>\d{1,2}):(?P<minute>\d{2})\s*(?P<indicator>am|pm|веч|дня|утра|ночи|дп|пп)?\b", text, re.IGNORECASE)

            if time_match:
                hour_val, minute_val = _parse_time_str_to_24h(time_match.group(0))
            else:
                hour_val, minute_val = 12, 0

            today = _now_local().date()
            year_val = today.year
            if month_val < today.month:
                year_val += 1
            try:
                return datetime(year_val, month_val, day_val, hour_val, minute_val)
            except ValueError:
                pass

    return None


def _persist_report_geo(
    report_id: int, lat: float, lng: float, address: str | None
) -> None:
    db = SessionLocal()
    try:
        report = db.query(Report).filter(Report.id == report_id).first()
        if not report:
            return
        changed = False
        if report.lat is None:
            report.lat = lat
            changed = True
        if report.lng is None:
            report.lng = lng
            changed = True
        if address and (not report.address or report.address != address):
            report.address = address
            changed = True
        if changed:
            db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()


async def _fetch_local_reports(
    limit: int, *, public_only: bool = False, city: str = "nizhnevartovsk"
) -> list[dict[str, Any]]:
    db = SessionLocal()
    try:
        query = db.query(Report)
        since = _now_local() - timedelta(days=30)
        query = query.filter(Report.created_at >= since)
        if public_only:
            query = query.filter(
                (Report.source.like("vk:%"))
                | (Report.source.like("tg:%"))
                | (Report.source.like("telegram:%"))
            )

        # Приложение работает только с Нижневартовском
        from sqlalchemy import or_
        query = query.filter(or_(Report.city == "nizhnevartovsk", Report.city == None, Report.city == ""))

        reports = query.order_by(Report.created_at.desc()).limit(limit).all()
        return [
            {
                "id": report.id,
                "title": report.title,
                "summary": report.title,
                "description": report.to_dict()["description"],
                "address": report.address,
                "lat": report.lat,
                "lng": report.lng,
                "category": _normalize_category(report.category),
                "status": report.status,
                "source": report.source,
                "city": report.city,
                "created_at": report.created_at.isoformat()
                if report.created_at
                else None,
                "updated_at": report.updated_at.isoformat()
                if report.updated_at
                else None,
                "images": report.to_dict().get("images") or [],
                "post_link": None,
            }
            for report in reports
        ]
    finally:
        db.close()


def _city_viewbox(report_city: str) -> str | None:
    """Viewbox города из _CITY_PROFILES (None — если профиль не найден)."""
    try:
        from services.Backend.comprehensive_marker_geofix import (
            _CITY_PROFILES,
            _city_key,
        )

        city_key = _city_key(report_city, "")
        profile = _CITY_PROFILES.get(city_key)
        return profile["viewbox"] if profile else None
    except Exception:
        return None


async def _ensure_report_address(
    report: dict[str, Any], lat: Any, lng: Any
) -> None:
    if _normalize_report_address(report) is not None:
        return
    if lat is None or lng is None:
        return
    try:
        from services.geo_service import resolve_address_from_coords

        report["address"] = await resolve_address_from_coords(
            float(lat),
            float(lng),
            existing=report.get("address"),
        )
        _normalize_report_address(report)
    except Exception as exc:
        logger.debug("Reverse geocode for report %s failed: %s", report.get("id"), exc)


async def _enrich_report(report: dict[str, Any]) -> dict[str, Any] | None:
    source = str(report.get("source") or "")
    source_lower = source.lower()
    report_city = str(report.get("city") or "").strip().lower() or "nizhnevartovsk"
    if source_lower.startswith("tg:") or source_lower.startswith("telegram:") or source_lower.startswith("vk:"):
        text = "\n".join(filter(None, [report.get("title"), report.get("description")]))
        if _is_weather_post(text):
            return None

    lat = report.get("lat")
    lng = report.get("lng")
    normalized_address = _normalize_report_address(report)
    if (
        (lat is None or lng is None)
        and MAP_FEED_ENABLE_GEOPARSE
        and _is_public_source(source)
    ):
        text = "\n".join(filter(None, [report.get("title"), report.get("description")]))
        geo = await geoparse(
            text=text,
            ai_address=normalized_address,
            location_hints=normalized_address,
            city=report_city,
        )
        lat = geo.get("lat")
        lng = geo.get("lng")
        if geo.get("address"):
            report["address"] = geo["address"]
            normalized_address = _normalize_report_address(report)
        # Персистим только координаты внутри viewbox города — мусор из
        # геопарсинга не должен «замораживаться» в БД как доверенный
        if lat is not None and lng is not None and report.get("id") is not None:
            try:
                flat, flng = float(lat), float(lng)
                viewbox = _city_viewbox(report_city)
                if viewbox is None:
                    lon_min, lat_min, lon_max, lat_max = 76.42, 60.85, 76.70, 61.02
                else:
                    lon_min, lat_min, lon_max, lat_max = (
                        float(v) for v in viewbox.split(",")
                    )
                if lat_min <= flat <= lat_max and lon_min <= flng <= lon_max:
                    await asyncio.to_thread(
                        _persist_report_geo,
                        int(report["id"]),
                        flat,
                        flng,
                        normalized_address,
                    )
                else:
                    lat = lng = None
            except (TypeError, ValueError):
                lat = lng = None

    await _ensure_report_address(report, lat, lng)
    normalized_address = _normalize_report_address(report)

    title_val = str(report.get("title") or report.get("summary") or "")
    desc_val = str(report.get("description") or "")
    addr_val = str(report.get("address") or normalized_address or "")

    from services.Backend.comprehensive_marker_geofix import (
        _CITY_PROFILES,
        _city_key,
        haversine_distance_m,
        load_knowledge_base,
        resolve_with_city,
    )

    city_key = _city_key(report_city, addr_val)
    profile = _CITY_PROFILES.get(city_key, _CITY_PROFILES["nizhnevartovsk"])

    # Координаты из БД считаем валидными, если они внутри viewbox своего города
    # и не совпадают с дефолтным центром другого города (след старого бага,
    # когда NSK-маркеры затирались центром Нижневартовска).
    coords_valid = False
    if lat is not None and lng is not None:
        try:
            flat, flng = float(lat), float(lng)
            lon_min, lat_min, lon_max, lat_max = (
                float(v) for v in profile["viewbox"].split(",")
            )
            in_viewbox = lat_min <= flat <= lat_max and lon_min <= flng <= lon_max
            is_foreign_default = any(
                key != city_key
                and haversine_distance_m(flat, flng, p["center"][0], p["center"][1]) < 50.0
                for key, p in _CITY_PROFILES.items()
            )
            coords_valid = in_viewbox and not is_foreign_default
        except (TypeError, ValueError):
            coords_valid = False

    if not coords_valid:
        houses_kb, inst_kb, street_kb = load_knowledge_base()
        (target_lat, target_lng), _geo_src = resolve_with_city(
            addr_val, title_val, desc_val, city_key, houses_kb, inst_kb, street_kb
        )
        if _geo_src != "city_center_default":
            lat = target_lat
            lng = target_lng
            report["lat"] = lat
            report["lng"] = lng
            if report.get("id") is not None:
                await asyncio.to_thread(
                    _persist_report_geo,
                    int(report["id"]),
                    float(lat),
                    float(lng),
                    report.get("address"),
                )
        else:
            # Нераспознанный адрес: центр города — лишь отображаемый фолбэк,
            # не подставляем и не персистим его, иначе маркер навсегда
            # «прилипнет» к центру и никогда не переисправится.
            report["lat"] = None
            report["lng"] = None

    if _cleanup_reason(report) is not None:
        return None

    marker_summary = (
        build_marker_summary(
            report.get("title") or report.get("summary"),
            report.get("description"),
            max_len=120,
        )
        or "Сообщение"
    )

    full_desc = str(report.get("description") or report.get("title") or report.get("summary") or "Сообщение").strip()

    images = report.get("images") or []
    if not images:
        rep_id = report.get("id") or 1
        rep_title = report.get("title") or report.get("summary") or "Сигнал"
        rep_cat = report.get("category") or "Город"
        seed = (hash(f"{rep_id}_{rep_title}") & 0x7fffffff) % 1000 + 1
        import urllib.parse
        # Build a detailed prompt for realistic city infrastructure photos (1:1 square to prevent squishing)
        cat_context = {
            "ЖКХ": "broken utility infrastructure, damaged pipes or heating in a residential area",
            "Дороги": "pothole or cracked asphalt on a city road",
            "Благоустройство": "neglected public space, overgrown grass, broken bench or playground",
            "Безопасность": "dark unlit street or broken streetlight in a residential area",
            "Мусор": "overflowing garbage container near an apartment building",
            "Парковки": "illegally parked cars blocking a sidewalk",
            "Транспорт": "bus stop in poor condition or traffic issue",
        }.get(rep_cat, "urban infrastructure issue in a city")
        photo_prompt = (
            f"ultra photorealistic documentary photo, {cat_context}, {rep_title}, "
            f"shot on Sony A7IV 35mm f/1.8 lens, natural outdoor daylight, "
            f"authentic Siberian city Nizhnevartovsk, detailed textures, 8k resolution, raw photo style"
        )
        encoded_prompt = urllib.parse.quote(photo_prompt)
        images = [f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=2048&height=2048&seed={seed}&nologo=true&model=flux-realism"]

    return {
        "id": f"report-{report.get('id')}",
        "origin_id": report.get("id"),
        "summary": marker_summary,
        "description": full_desc,
        "lat": float(lat),
        "lng": float(lng),
        "address": report.get("address") or f"г. Нижневартовск, сигнал #{report.get('id')}",
        "category": _normalize_category(report.get("category")),
        "status": report.get("status") or "open",
        "source": source,
        "source_label": _source_label(source),
        "source_kind": (
            "event"
            if _is_event_category(report.get("category"))
            else ("public" if _is_public_source(source) else "report")
        ),
        "layer": "city_events" if _is_event_category(report.get("category")) else "problems",
        "address_confidence": _address_confidence(report, lat, lng),
        "source_table": "reports",
        "created_at": report.get("created_at"),
        "updated_at": report.get("updated_at"),
        "images": images,
        "likes_count": report.get("likes_count") or 0,
        "dislikes_count": report.get("dislikes_count") or 0,
        "supporters": report.get("supporters") or 0,
        "link": report.get("post_link") or None,
    }


async def _load_public_markers(limit: int, city: str = "nizhnevartovsk") -> list[dict[str, Any]]:
    candidate_limit = max(limit * 2, 180)
    public_candidate_limit = max(limit, 120)

    recent_reports, recent_public_reports = await asyncio.gather(
        _fetch_local_reports(candidate_limit, city=city),
        _fetch_local_reports(public_candidate_limit, public_only=True, city=city),
    )

    merged_reports: list[dict[str, Any]] = []
    seen_ids: set[int] = set()

    for report in [*recent_public_reports, *recent_reports]:
        report_id = int(report.get("id") or 0)
        if report_id in seen_ids:
            continue
        seen_ids.add(report_id)
        merged_reports.append(report)

    reports_with_coords = [
        report
        for report in merged_reports
        if report.get("lat") is not None and report.get("lng") is not None
    ]
    reports_without_coords = [
        report
        for report in merged_reports
        if report.get("lat") is None or report.get("lng") is None
    ]

    pending_quota = min(max(limit // 3, 8), 24)
    prioritized_reports = [
        *reports_with_coords,
        *reports_without_coords[:pending_quota],
    ]

    tasks = [
        asyncio.wait_for(
            _enrich_report(report),
            timeout=MAP_PER_REPORT_TIMEOUT_SECONDS,
        )
        for report in prioritized_reports
    ]
    enriched = await asyncio.gather(*tasks, return_exceptions=True)
    markers = [item for item in enriched if isinstance(item, dict) and item]

    public_markers = [item for item in markers if item.get("source_kind") == "public"]
    other_markers = [item for item in markers if item.get("source_kind") != "public"]
    public_markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    other_markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    public_markers = _dedupe_marker_records(public_markers)
    other_markers = _dedupe_marker_records(other_markers)

    public_quota = min(max(limit // 4, 12), 40)
    selected = public_markers[:public_quota]
    remaining = max(limit - len(selected), 0)
    selected.extend(other_markers[:remaining])
    selected.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return selected


def _is_weather_post(text: str) -> bool:
    text_lower = text.lower()
    weather_keywords = [
        "прогноз погоды", "градус", "синоптик", "погод", 
        "температур", "осадки", "пасмурно", "облачно", 
        "ветер до", "м/с", "в нижневартовске ожидает"
    ]
    # Check if text contains multiple weather markers (e.g. forecast list)
    matches = sum(1 for kw in weather_keywords if kw in text_lower)
    return matches >= 2 or any(intro in text_lower for intro in ["прогноз погоды", "погода на сегодня", "ожидается температура"])


def _is_tg_event_report(report: dict[str, Any]) -> bool:
    source = str(report.get("source") or "").lower()
    if not (source.startswith("tg:") or source.startswith("telegram:")):
        return False
    text = _report_text(report)
    if _is_weather_post(text):
        return False
    if _normalize_category(report.get("category")) == "Мероприятие":
        return True
    return any(keyword in text for keyword in TG_EVENT_KEYWORDS)


def _has_geocoded_street_address(report: dict[str, Any]) -> bool:
    addr = _normalize_report_address(report)
    if not addr:
        return False
    lower = addr.lower()
    if lower.startswith("gps "):
        return False
    street_markers = (
        "ул.",
        "ул ",
        "улиц",
        "просп",
        "пер.",
        "пер ",
        "мкр",
        "микрорайон",
        "наб.",
        "набереж",
        "бульвар",
        "б-р",
        "проезд",
    )
    if any(marker in lower for marker in street_markers):
        return True
    return len(addr.strip()) >= 10


def _fetch_tg_event_reports(days: int = 30, city: str = "nizhnevartovsk") -> list[dict[str, Any]]:
    db = SessionLocal()
    try:
        since = _now_local() - timedelta(days=days)
        query = db.query(Report).filter(
            Report.created_at >= since,
            Report.lat.isnot(None),
            Report.lng.isnot(None),
            (
                Report.source.like("tg:%")
                | Report.source.like("telegram:%")
            ),
        )
        # Приложение работает только с Нижневартовском
        from sqlalchemy import or_
        query = query.filter(or_(Report.city == "nizhnevartovsk", Report.city == None, Report.city == ""))

        rows = query.order_by(Report.created_at.desc()).limit(400).all()
        return [
            {
                "id": row.id,
                "title": row.title,
                "summary": row.title,
                "description": row.to_dict()["description"],
                "address": row.address,
                "lat": row.lat,
                "lng": row.lng,
                "category": row.category,
                "status": row.status,
                "source": row.source,
                "created_at": row.created_at.isoformat()
                if row.created_at
                else None,
                "updated_at": row.updated_at.isoformat()
                if row.updated_at
                else None,
                "images": row.to_dict().get("images") or [],
                "post_link": None,
            }
            for row in rows
        ]
    finally:
        db.close()


def _report_to_tg_event_marker(report: dict[str, Any]) -> dict[str, Any] | None:
    if not _is_tg_event_report(report):
        return None
    if not _has_geocoded_street_address(report):
        return None

    lat = report.get("lat")
    lng = report.get("lng")
    if lat is None or lng is None:
        return None

    source = str(report.get("source") or "")
    marker_summary = (
        build_marker_summary(
            report.get("title") or report.get("summary"),
            report.get("description"),
            max_len=120,
        )
        or str(report.get("title") or "Мероприятие")
    )
    full_desc = str(report.get("description") or report.get("title") or report.get("summary") or "Мероприятие").strip()

    # Extract event start datetime from description/title
    event_dt = _extract_event_datetime(full_desc) or _extract_event_datetime(marker_summary)
    created_at_val = report.get("created_at")
    event_date_val = None
    if event_dt:
        created_at_val = event_dt.isoformat()
        event_date_val = event_dt.date().isoformat()
        start_time_str = event_dt.strftime("%H:%M")
        if start_time_str not in marker_summary:
            marker_summary = f"[{start_time_str}] {marker_summary}"
        if "Время начала:" not in full_desc:
            full_desc = f"🕒 Время начала: {start_time_str}\n\n{full_desc}"
    else:
        # Fallback: extract date from created_at if possible
        if created_at_val:
            try:
                event_date_val = datetime.fromisoformat(created_at_val.replace("Z", "")).date().isoformat()
            except Exception:
                pass

    return {
        "id": f"tg-event-{report.get('id')}",
        "origin_id": report.get("id"),
        "summary": marker_summary,
        "description": full_desc,
        "lat": float(lat),
        "lng": float(lng),
        "address": report.get("address"),
        "category": "Мероприятие",
        "status": report.get("status") or "open",
        "source": source,
        "source_label": _source_label(source),
        "source_kind": "event",
        "layer": "city_events",
        "address_confidence": "high",
        "source_table": "reports",
        "created_at": created_at_val,
        "updated_at": report.get("updated_at"),
        "event_date": event_date_val,
        "images": report.get("images") or [],
        "likes_count": report.get("likes_count") or 0,
        "dislikes_count": report.get("dislikes_count") or 0,
        "supporters": report.get("supporters") or 0,
        "link": report.get("post_link") or None,
    }


def _load_tg_event_markers(days: int = 30, city: str = "nizhnevartovsk") -> list[dict[str, Any]]:
    markers: list[dict[str, Any]] = []
    for report in _fetch_tg_event_reports(days, city):
        marker = _report_to_tg_event_marker(report)
        if marker:
            markers.append(marker)
    markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return _dedupe_marker_records(markers)


async def _fetch_event_detail(client: httpx.AsyncClient, url: str) -> str | None:
    try:
        response = await client.get(url, timeout=5.0)
        if response.status_code != 200:
            return None
        soup = BeautifulSoup(response.text, "html.parser")

        # Try meta og:description
        meta_desc = soup.find("meta", property="og:description")
        desc_content = meta_desc.get("content") if meta_desc else None

        # Try div class lead
        lead_div = soup.select_one(".lead")
        lead_text = lead_div.get_text(" ", strip=True) if lead_div else None

        # Try main news content
        content_div = soup.select_one(".news-detail") or soup.select_one(".detail-text") or soup.select_one(".content")
        content_text = content_div.get_text(" ", strip=True) if content_div else None

        # Choose the best text: prefer detailed content if available and longer than lead
        chosen = ""
        if content_text and len(content_text) > 50:
            chosen = content_text
        elif lead_text and len(lead_text) > 50:
            chosen = lead_text
        elif desc_content:
            chosen = desc_content

        if chosen:
            # Clean up text
            chosen = chosen.replace("Афиша Нижневартовска.", "").strip()
            chosen = re.sub(r"\s+", " ", chosen)
            return chosen
    except Exception as e:
        logger.warning("Error fetching detail for %s: %s", url, e)
    return None


async def _load_city_events_uncached(city: str = "nizhnevartovsk") -> dict[str, Any]:
    """Load current and upcoming city events for the map layer from multiple sources (scraped & local JSON)."""
    scraped_events: list[dict[str, Any]] = []
    now = _now_local()
    today = now.date()
    max_date = today + timedelta(days=CITY_EVENT_LOOKAHEAD_DAYS)

    # 1. Scrape official afisha
    scraped_afisha_ok = False
    if city == "nizhnevartovsk":
        try:
            async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
                response = await client.get(AFISHA_URL)
                response.raise_for_status()
            soup = BeautifulSoup(response.text, "html.parser")
            cards = soup.select(".single-news")
            if not cards:
                cards = soup.select(".news-item, .event-item, .afisha-item, .card, .single-afisha")
            if not cards:
                cards = soup.select("a[href*='/afisha/']")

            # Collect candidates scheduled for today
            today_candidates = []
            for index, card in enumerate(cards, start=1):
                text = card.get_text(" ", strip=True)
                event_dt = _extract_event_datetime(text)
                if not event_dt:
                    continue

                event_date = event_dt.date()
                if event_date < today or event_date > max_date:
                    continue

                event_end = event_dt + timedelta(hours=1)
                if event_end < now:
                    continue

                venue = await _resolve_event_venue(text=text)
                if not venue:
                    continue

                link = None
                anchor = card.find("a", href=True)
                if anchor:
                    link = urljoin(AFISHA_URL, anchor["href"])

                today_candidates.append({
                    "index": index,
                    "text": text,
                    "event_dt": event_dt,
                    "venue": venue,
                    "link": link
                })

            # Concurrent fetch for detail descriptions
            async def fetch_desc(candidate):
                link = candidate["link"]
                if link:
                    async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
                        detail_desc = await _fetch_event_detail(client, link)
                        if detail_desc:
                            return detail_desc
                return candidate["text"]

            descs = await asyncio.gather(*(fetch_desc(c) for c in today_candidates), return_exceptions=True)

            for idx, candidate in enumerate(today_candidates):
                desc = descs[idx] if not isinstance(descs[idx], Exception) and descs[idx] else candidate["text"]
                event_date = candidate["event_dt"].date()
                start_time_str = candidate["event_dt"].strftime("%H:%M")
                title = _extract_event_title(candidate["text"])
                summary = f"[{start_time_str}] {title}"
                desc = f"🕒 Время начала: {start_time_str}\nМесто: {candidate['venue']['name']}\n\n{desc}"
                event = {
                    "id": f"event-afisha-{event_date.isoformat()}-{candidate['index']}",
                    "summary": summary,
                    "description": desc,
                    "lat": candidate["venue"]["lat"],
                    "lng": candidate["venue"]["lng"],
                    "address": candidate["venue"]["address"],
                    "venue": candidate["venue"]["name"],
                    "category": "Мероприятие",
                    "status": "open",
                    "source": "official:afisha",
                    "source_label": "Афиша",
                    "source_kind": "event",
                    "layer": "city_events",
                    "event_date": event_date.isoformat(),
                    "source_table": "events",
                    "created_at": candidate["event_dt"].isoformat(),
                    "updated_at": candidate["event_dt"].isoformat(),
                    "images": [],
                    "likes_count": 0,
                    "dislikes_count": 0,
                    "supporters": 0,
                    "link": candidate["link"],
                }
                scraped_events.append(event)
            if scraped_events:
                scraped_afisha_ok = True
        except Exception as e:
            logger.warning("Live afisha scrape failed: %s", e)

    if not scraped_events:
        fallback_afisha, _ = _load_scraped_events_cache()
        if fallback_afisha:
            logger.info("Afisha scraping failed/empty. Loaded %d fallback events from file cache.", len(fallback_afisha))
            scraped_events.extend(fallback_afisha)

    # 1b. Scrape GorodZovet
    gorodzovet_events: list[dict[str, Any]] = []
    scraped_gz_ok = False
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        gz_city = "nizhnevartovsk"
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True, headers=headers) as client:
            response = await client.get(f"https://gorodzovet.ru/{gz_city}/")
            response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")
        blocks = soup.select(".event-block")
        for index, block in enumerate(blocks, start=1):
            image_div = block.select_one(".event-image")
            link = None
            if image_div and image_div.has_attr("data-link"):
                link = "https://gorodzovet.ru" + image_div["data-link"]

            img = block.select_one("img")
            title = img["alt"] if img and img.has_attr("alt") else ""

            title_a = block.select_one(".event-link")
            if title_a:
                title = title_a.get_text(strip=True)
                if title_a.has_attr("data-link") and not link:
                    link = "https://gorodzovet.ru" + title_a["data-link"]

            if not title:
                continue

            title = title[:150]

            date_div = block.select_one(".event-date")
            date_str = ""
            if date_div:
                date_str = date_div.get_text(" ", strip=True)

            meta_div = block.select_one(".event-meta")
            place = "Нижневартовск"
            if meta_div:
                place = meta_div.get_text(" ", strip=True)

            event_dt = now
            ru_months = {
                "янв": 1, "фев": 2, "мар": 3, "апр": 4, "май": 5, "июн": 6,
                "июл": 7, "авг": 8, "сен": 9, "окт": 10, "ноя": 11, "дек": 12
            }
            date_match = re.search(
                r'(?:(?P<day1>\d{1,2})\s+(?P<month1>[а-яёА-ЯЁ]{3,8}))|(?:(?P<month2>[а-яёА-ЯЁ]{3,8})\s+(?P<day2>\d{1,2}))',
                date_str,
                re.IGNORECASE
            )
            if date_match:
                if date_match.group("month1"):
                    month_name = date_match.group("month1")[:3].lower()
                    day_val = int(date_match.group("day1"))
                else:
                    month_name = date_match.group("month2")[:3].lower()
                    day_val = int(date_match.group("day2"))
                month_val = ru_months.get(month_name, today.month)
                year_val = today.year
                if month_val < today.month:
                    year_val += 1
                try:
                    event_dt = datetime(year_val, month_val, day_val, 12, 0)
                except ValueError:
                    event_dt = now

            if event_dt + timedelta(hours=1) < now:
                continue

            event_date = event_dt.date()
            if event_date < today or event_date > max_date:
                continue

            venue = await _resolve_event_venue(text=f"{title}. {place}", place_hint=place)
            if not venue:
                continue

            start_time_str = event_dt.strftime("%H:%M")
            summary = f"[{start_time_str}] {title}"
            desc = f"🕒 Время начала: {start_time_str}\n\n{title}. Дата: {date_str}. Место: {place}"
            event = {
                "id": f"event-gz-{event_date.isoformat()}-{index}",
                "summary": summary,
                "description": desc,
                "lat": venue["lat"],
                "lng": venue["lng"],
                "address": venue["address"],
                "venue": venue["name"],
                "category": "Мероприятие",
                "status": "open",
                "source": "official:gorodzovet",
                "source_label": "ГородЗовёт",
                "source_kind": "event",
                "layer": "city_events",
                "event_date": event_date.isoformat(),
                "source_table": "events",
                "created_at": event_dt.isoformat(),
                "updated_at": event_dt.isoformat(),
                "images": [],
                "likes_count": 0,
                "dislikes_count": 0,
                "supporters": 0,
                "link": link,
            }
            gorodzovet_events.append(event)
        if gorodzovet_events:
            scraped_gz_ok = True
    except Exception as e:
        logger.warning("GorodZovet live afisha scrape failed: %s", e)

    if not gorodzovet_events:
        _, fallback_gz = _load_scraped_events_cache()
        if fallback_gz:
            logger.info("GorodZovet scraping failed/empty. Loaded %d fallback events from file cache.", len(fallback_gz))
            gorodzovet_events.extend(fallback_gz)

    # 1c. Update persistent fallback cache if we got new data
    if scraped_afisha_ok or scraped_gz_ok:
        cached_afisha, cached_gz = _load_scraped_events_cache()
        final_afisha = scraped_events if scraped_afisha_ok else cached_afisha
        final_gz = gorodzovet_events if scraped_gz_ok else cached_gz
        _save_scraped_events_cache(final_afisha, final_gz)

    # 2. Parse local city_events_week.json
    local_events: list[dict[str, Any]] = []
    if city == "nizhnevartovsk":
        fallback_paths = [
            _PROJECT_ROOT / "data" / "city_events_week.json",
            Path(__file__).resolve().parents[3] / "data" / "city_events_week.json",
        ]
        for path in fallback_paths:
            if path.exists():
                try:
                    with open(path, encoding="utf-8") as f:
                        data = json.load(f)

                    raw_events = []
                    if isinstance(data.get("today"), list):
                        raw_events.extend(data["today"])
                    if isinstance(data.get("week"), list):
                        raw_events.extend(data["week"])

                    # Calculate time difference to shift static March 2026 events to present
                    base_dt = datetime.fromisoformat("2026-03-13T00:00:00")
                    now_naive = datetime.now()
                    delta = now_naive - base_dt

                    for item in raw_events:
                        if not isinstance(item, dict):
                            continue

                        evt = dict(item)
                        # Shift all relevant dates
                        for date_key in ("created_at", "event_start_at", "updated_at"):
                            val = evt.get(date_key)
                            if isinstance(val, str):
                                try:
                                    dt = datetime.fromisoformat(val.replace("Z", ""))
                                    new_dt = dt + delta
                                    evt[date_key] = new_dt.isoformat()
                                except Exception:
                                    pass

                        evt_date = evt.get("event_date")
                        if isinstance(evt_date, str):
                            try:
                                dt = datetime.strptime(evt_date, "%Y-%m-%d")
                                new_dt = dt + delta
                                evt["event_date"] = new_dt.date().isoformat()
                            except Exception:
                                pass

                        local_events.append(evt)
                    logger.info("Loaded %d events from local file %s", len(local_events), path)
                    break
                except Exception as exc:
                    logger.error("Failed to load local events: %s", exc)

    # 3. Combine & Deduplicate (Event-specific deduplication)
    combined = [*scraped_events, *gorodzovet_events, *local_events]

    unique_events = []
    for evt in combined:
        is_dup = False
        for u_evt in unique_events:
            # 1. Check link / origin_id
            link1 = evt.get("link") or evt.get("origin_id")
            link2 = u_evt.get("link") or u_evt.get("origin_id")
            if link1 and link2 and link1 == link2:
                is_dup = True
                if (evt.get("lat") and not u_evt.get("lat")) or (len(evt.get("description") or "") > len(u_evt.get("description") or "")):
                    unique_events.remove(u_evt)
                    unique_events.append(evt)
                break

            # 2. Check date + location + title similarity
            date1 = evt.get("event_date")
            date2 = u_evt.get("event_date")
            if date1 and date2 and date1 == date2:
                same_location = False
                lat1, lng1 = evt.get("lat"), evt.get("lng")
                lat2, lng2 = u_evt.get("lat"), u_evt.get("lng")
                if lat1 and lng1 and lat2 and lng2:
                    dist = abs(float(lat1) - float(lat2)) + abs(float(lng1) - float(lng2))
                    if dist < 0.001:
                        same_location = True

                addr1 = evt.get("address") or evt.get("venue")
                addr2 = u_evt.get("address") or u_evt.get("venue")
                if addr1 and addr2 and addr1.strip().lower() == addr2.strip().lower():
                    same_location = True

                if same_location:
                    title1 = evt.get("summary") or evt.get("title") or ""
                    title2 = u_evt.get("summary") or u_evt.get("title") or ""
                    if _titles_are_similar(title1, title2):
                        is_dup = True
                        if len(evt.get("description") or "") > len(u_evt.get("description") or ""):
                            unique_events.remove(u_evt)
                            unique_events.append(evt)
                        break
        if not is_dup:
            unique_events.append(evt)

    deduped = _dedupe_marker_records(unique_events)

    today_str = today.isoformat()
    today_events_with_coords = []
    all_events_with_coords = []
    addressless_events = []
    for evt in deduped:
        evt_date = evt.get("event_date")
        lat = evt.get("lat")
        lng = evt.get("lng")
        if lat is not None and lng is not None and lat != 0.0 and lng != 0.0:
            all_events_with_coords.append(evt)
            if evt_date == today_str:
                today_events_with_coords.append(evt)
        else:
            # Показываем адресные события без координат только за сегодня
            if evt_date == today_str:
                addressless_events.append(evt)

    today_events_with_coords.sort(key=lambda item: item.get("created_at") or "")
    all_events_with_coords.sort(key=lambda item: item.get("created_at") or "")
    addressless_events.sort(key=lambda item: item.get("created_at") or "")

    logger.info("Combined events from sources. Scraped: %d, GorodZovet: %d, Local: %d. Deduped: %d. Filtered for today: %d, total with coords: %d, addressless: %d",
                len(scraped_events), len(gorodzovet_events), len(local_events), len(deduped), len(today_events_with_coords), len(all_events_with_coords), len(addressless_events))

    return {
        "today": today_events_with_coords,
        "events": all_events_with_coords,
        "addressless": addressless_events,
        "meta": {
            "date": today.isoformat(),
            "date_to": max_date.isoformat(),
            "source": AFISHA_URL,
            "cache_ttl_seconds": MAP_EVENTS_CACHE_TTL_SECONDS,
            "scraped_count": len(scraped_events),
            "gorodzovet_count": len(gorodzovet_events),
            "local_count": len(local_events),
        },
    }


_events_caches: dict[str, dict[str, Any]] = {}

async def _load_city_events(*, force_refresh: bool = False, city: str = "nizhnevartovsk") -> dict[str, Any]:
    """Return today's city-event layer with cache protection for map polling."""
    now = _now_local()
    today_key = now.date().isoformat()
    if city not in _events_caches:
        _events_caches[city] = {
            "date": None,
            "expires_at": None,
            "payload": None,
        }
    city_cache = _events_caches[city]
    cached_payload = city_cache.get("payload")
    cached_date = city_cache.get("date")
    expires_at = city_cache.get("expires_at")

    if (
        not force_refresh
        and cached_payload is not None
        and cached_date == today_key
        and isinstance(expires_at, datetime)
        and expires_at > now
    ):
        return cached_payload

    async with _events_cache_lock:
        cached_payload = city_cache.get("payload")
        cached_date = city_cache.get("date")
        expires_at = city_cache.get("expires_at")
        if (
            not force_refresh
            and cached_payload is not None
            and cached_date == today_key
            and isinstance(expires_at, datetime)
            and expires_at > now
        ):
            return cached_payload

        payload = await _load_city_events_uncached(city=city)
        expires = now + timedelta(seconds=MAP_EVENTS_CACHE_TTL_SECONDS)
        payload["meta"] = {
            **(payload.get("meta") or {}),
            "generated_at": now.isoformat(),
            "expires_at": expires.isoformat(),
        }
        city_cache.update(
            {
                "date": today_key,
                "expires_at": expires,
                "payload": payload,
            }
        )
        return payload


@router.get("/map/feed")
async def get_map_feed(
    limit: int = Query(250, ge=1, le=500),
    bbox: str | None = Query(
        None,
        description="Optional minLng,minLat,maxLng,maxLat viewport filter.",
    ),
    layers: str = Query("all", description="Comma-separated: all, problems, events."),
    refresh: bool = Query(False, description="Bypass short feed cache."),
    event_days: int = Query(7, ge=1, le=30, description="Event lookahead in days."),
    city: str = Query("nizhnevartovsk", description="City to filter signals and events."),
):
    parsed_bbox = _parse_bbox(bbox)
    parsed_layers = {item.strip().lower() for item in layers.split(",") if item.strip()} or {"all"}
    cache_key = (limit, parsed_bbox, tuple(sorted(parsed_layers)), event_days, city)
    now = _now_local()
    if (
        not refresh
        and _feed_cache.get("key") == cache_key
        and isinstance(_feed_cache.get("expires_at"), datetime)
        and _feed_cache["expires_at"] > now
        and isinstance(_feed_cache.get("payload"), dict)
    ):
        payload = dict(_feed_cache["payload"])
        payload["cache_hit"] = True
        return payload

    async with _feed_cache_lock:
        now = _now_local()
        if (
            not refresh
            and _feed_cache.get("key") == cache_key
            and isinstance(_feed_cache.get("expires_at"), datetime)
            and _feed_cache["expires_at"] > now
            and isinstance(_feed_cache.get("payload"), dict)
        ):
            payload = dict(_feed_cache["payload"])
            payload["cache_hit"] = True
            return payload

        payload = await _build_map_feed(
            limit=limit,
            bbox=parsed_bbox,
            layers=parsed_layers,
            force_refresh_events=refresh,
            event_days=event_days,
            city=city,
        )
        payload["cache_hit"] = False
        _feed_cache.update(
            {
                "key": cache_key,
                "expires_at": now + timedelta(seconds=MAP_FEED_CACHE_TTL_SECONDS),
                "payload": payload,
            }
        )
        return payload


async def _build_map_feed(
    *,
    limit: int,
    bbox: tuple[float, float, float, float] | None,
    layers: set[str],
    force_refresh_events: bool = False,
    event_days: int = 7,
    city: str = "nizhnevartovsk",
) -> dict[str, Any]:
    effective_limit = min(max(limit * 2 if bbox else limit, 50), 500)
    reports_task = asyncio.create_task(
        asyncio.wait_for(
            _load_public_markers(limit=effective_limit, city=city),
            timeout=MAP_REPORTS_TIMEOUT_SECONDS,
        )
    )
    events_task = asyncio.create_task(
        asyncio.wait_for(
            _load_city_events(force_refresh=force_refresh_events, city=city),
            timeout=MAP_EVENTS_TIMEOUT_SECONDS,
        )
    )
    tg_events_task = asyncio.create_task(
        asyncio.to_thread(_load_tg_event_markers, 30, city)
    )
    reports_result, events_result, tg_events_result = await asyncio.gather(
        reports_task,
        events_task,
        tg_events_task,
        return_exceptions=True,
    )

    reports = reports_result if isinstance(reports_result, list) else []
    events = events_result if isinstance(events_result, dict) else {"today": [], "meta": {}}
    tg_events = tg_events_result if isinstance(tg_events_result, list) else []

    # Filter Telegram/VK events to today only and not older than 1 hour after start
    now_local = _now_local()
    today_date = now_local.date()
    today_start = datetime.combine(today_date, datetime.min.time())
    today_end = datetime.combine(today_date, datetime.max.time())

    filtered_tg_events = []
    for evt in tg_events:
        evt_date_str = evt.get("event_date")
        if not evt_date_str:
            created_at_str = evt.get("created_at")
            if created_at_str:
                try:
                    evt_dt = datetime.fromisoformat(created_at_str.replace("Z", ""))
                    evt_date_str = evt_dt.date().isoformat()
                except Exception:
                    pass
        if evt_date_str == today_date.isoformat():
            filtered_tg_events.append(evt)

    raw_event_list = events.get("events") if isinstance(events.get("events"), list) else (events.get("today") if isinstance(events.get("today"), list) else [])

    filtered_event_rows = []
    for evt in raw_event_list:
        evt_dt_str = evt.get("created_at") or evt.get("event_start_at")
        evt_dt = None
        if evt_dt_str:
            try:
                evt_dt = datetime.fromisoformat(evt_dt_str.replace("Z", ""))
                if evt_dt.tzinfo is not None:
                    evt_dt = evt_dt.replace(tzinfo=None)
            except Exception:
                pass

        evt_date_str = evt.get("event_date")
        if not evt_date_str and evt_dt:
            evt_date_str = evt_dt.date().isoformat()

        if evt_date_str:
            try:
                evt_date = datetime.strptime(evt_date_str, "%Y-%m-%d").date()
                if evt_date == today_date:
                    filtered_event_rows.append(evt)
            except Exception:
                pass

    merged_event_rows = _dedupe_marker_records([*filtered_event_rows, *filtered_tg_events])
    if isinstance(events, dict):
        events = {**events, "today": [e for e in merged_event_rows if e.get("event_date") == today_date.isoformat()]}
    # Объекты строительства/ремонта больше не рисуются маркерами на карте —
    # они живут в отдельной вкладке «Паспорта объектов» (endpoint /api/v1/road-works).
    markers = [*reports, *merged_event_rows]

    markers = _filter_layers(markers, layers)
    markers = _filter_bbox(markers, bbox)
    markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    event_markers_all = [
        item
        for item in markers
        if item.get("source_kind") == "event" or _is_event_category(item.get("category"))
    ]
    report_markers_all = [item for item in markers if item not in event_markers_all]
    event_quota = min(len(event_markers_all), max(40, limit // 3))
    report_quota = max(limit - event_quota, 0)
    markers = [*event_markers_all[:event_quota], *report_markers_all[:report_quota]]
    markers.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    markers = markers[:limit]
    event_markers = [
        item
        for item in markers
        if item.get("source_kind") == "event" or _is_event_category(item.get("category"))
    ]
    return {
        "success": True,
        "generated_at": _now_local().isoformat(),
        "cache_ttl_seconds": MAP_FEED_CACHE_TTL_SECONDS,
        "counts": {
            "markers": len(markers),
            "public_reports": len(
                [item for item in markers if item.get("source_kind") == "public"]
            ),
            "events_today": len(event_markers),
            "high_confidence": len(
                [item for item in markers if item.get("address_confidence") == "high"]
            ),
        },
        "markers": markers,
        "reports": [item for item in markers if item not in event_markers],
        "events": events,
    }


@router.get("/map/events")
async def get_city_events_layer(
    refresh: bool = Query(False, description="Force refresh official afisha cache"),
):
    events = await _load_city_events(force_refresh=refresh)
    today_events = events.get("today") if isinstance(events, dict) else []
    return {
        "success": True,
        "generated_at": _now_local().isoformat(),
        "layer": "city_events",
        "counts": {
            "events_today": len(today_events) if isinstance(today_events, list) else 0,
        },
        "events": events,
    }
