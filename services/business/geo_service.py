import asyncio
import json
import logging
import os
import re
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx

from core.http_client import get_http_client
from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

logger = logging.getLogger(__name__)

CITY_NAME = os.getenv("GEO_CITY_NAME", "Нижневартовск")
CITY_CENTER = (60.9344, 76.5531)
CITY_VIEWBOX = "76.42,60.85,76.70,61.02"
GEO_MAX_RETRIES = int(os.getenv("GEO_MAX_RETRIES", "2"))
GEO_RETRY_DELAY = float(os.getenv("GEO_RETRY_DELAY", "0.8"))
GEO_CACHE_PATH = Path(os.getenv("GEO_CACHE_PATH", "data/geocode_cache.json"))
GEO_ENABLE_PHOTON = os.getenv("GEO_ENABLE_PHOTON", "true").lower() in {
    "1",
    "true",
    "yes",
}

_client: httpx.AsyncClient | None = None
_geo_semaphore: asyncio.Semaphore | None = None
_geo_cache: dict[str, tuple[float, float]] = {}
_geo_cache_loaded = False
_reverse_cache: dict[str, str] = {}
_reverse_cache_loaded = False
_local_points_loaded = False
_local_points: dict[str, tuple[float, float]] = {}
_REVERSE_CACHE_PATH = Path(os.getenv("REVERSE_GEO_CACHE_PATH", "data/reverse_geocode_cache.json"))
_REVERSE_REDIS_TTL = int(os.getenv("REVERSE_GEO_REDIS_TTL", str(86400 * 14)))

NV_LANDMARKS = {
    "самотлор": (60.9398, 76.5652),
    "озеро комсомольское": (60.9450, 76.5500),
    "комсомольское озеро": (60.9450, 76.5500),
    "сити центр": (60.9380, 76.5530),
    "югра молл": (60.9420, 76.5700),
    "автовокзал": (60.9410, 76.5730),
    "жд вокзал": (60.9560, 76.5850),
    "аэропорт": (60.9490, 76.4880),
    "площадь нефтяников": (60.9368, 76.5645),
    "администрация города": (60.9370, 76.5530),
    "парк победы": (60.9400, 76.5480),
    "ледовый дворец": (60.9420, 76.5650),
    "набережная": (60.9300, 76.5500),
    "старый вартовск": (60.9250, 76.5300),
}

NV_STREET_HINTS = {
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
    "героев самотлора",
    "декабристов",
    "дзержинского",
    "заводская",
    "набережная",
    "нововартовская",
    "молодежная",
    "московкина",
    "анисимковой",
    "петтухиной",
    "романтиков",
    "пушкина",
    "рябиновая",
    "октябрьская",
    "гагарина",
    "заозерный",
    "брусничная",
    "первомайская",
    "менделеева",
    "первостроителей",
    "шевелева",
    "северный",
    "поселковая",
    "самотлорская",
    "восточный",
    "озерная",
    "кедровая",
    "лесная",
    "геологов",
    "1п", "2п", "9п", "10п", "11п", "16п"
}

_STOPWORDS = {
    "около",
    "более",
    "менее",
    "через",
    "после",
    "перед",
    "возле",
    "рядом",
    "номер",
    "этаж",
    "подъезд",
    "травмпункте",
    "человека",
    "человек",
    "машин",
    "машины",
    "процентов",
    "лет",
    "минут",
}


def get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = get_http_client(
            timeout=15.0,
            proxy=None,
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
            follow_redirects=True,
        )
    return _client


def _normalize_key(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def _lookup_redis_spatial_cache(address: str) -> tuple[float, float] | None:
    """Redis spatial cache lookup (<1.5 ms resolution)."""
    try:
        import redis
        r_host = os.getenv("REDIS_HOST", "localhost")
        r_port = int(os.getenv("REDIS_PORT", "6379"))
        r = redis.Redis(host=r_host, port=r_port, socket_timeout=0.1, decode_responses=True)
        key = f"geo:nv:building:{_normalize_key(address)}"
        val = r.get(key)
        if val:
            parts = val.split(",")
            if len(parts) == 2:
                return float(parts[0]), float(parts[1])
    except Exception:
        pass
    return None


def _ensure_geo_cache_loaded() -> None:
    global _geo_cache_loaded
    if _geo_cache_loaded:
        return
    _geo_cache_loaded = True
    try:
        if not GEO_CACHE_PATH.exists():
            return
        raw = json.loads(GEO_CACHE_PATH.read_text(encoding="utf-8"))
        if not isinstance(raw, dict):
            return
        for key, value in raw.items():
            if (
                isinstance(key, str)
                and isinstance(value, list)
                and len(value) == 2
                and all(isinstance(item, (int, float)) for item in value)
            ):
                _geo_cache[key] = (float(value[0]), float(value[1]))
    except Exception as exc:
        logger.warning("Geo cache load failed: %s", exc)


def _persist_geo_cache() -> None:
    try:
        GEO_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        payload = {key: [value[0], value[1]] for key, value in _geo_cache.items()}
        GEO_CACHE_PATH.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except Exception as exc:
        logger.warning("Geo cache persist failed: %s", exc)


def _remember_coordinates(
    address: str, coords: tuple[float, float]
) -> tuple[float, float] | None:
    if not is_coords_in_city(coords[0], coords[1]):
        logger.warning("Coords %s for '%s' are outside Nizhnevartovsk limits", coords, address)
        return None
    _ensure_geo_cache_loaded()
    _geo_cache[_normalize_key(address)] = coords
    _persist_geo_cache()
    return coords


def _load_local_points() -> None:
    global _local_points_loaded
    if _local_points_loaded:
        return
    _local_points_loaded = True

    # ВНИМАНИЕ: реестр nizhnevartovsk_houses.json и старые ручные overrides
    # системно расходятся с реальными координатами OSM на 0.5–2 км
    # (проверено сверкой с Nominatim 29.08.2026). Они больше НЕ используются
    # как доверенный источник точек домов — только как офлайн-фолбэк
    # в конце цепочки get_coordinates().

    # Load camera landmarks (only as fallbacks)
    candidate_files = [
        Path("public/cameras_nv.json"),
        Path("services/Frontend/assets/cameras_nv.json"),
    ]
    for file_path in candidate_files:
        try:
            if not file_path.exists():
                continue
            items = json.loads(file_path.read_text(encoding="utf-8"))
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                name = str(item.get("n") or "").strip()
                lat = item.get("lat")
                lng = item.get("lng")
                if (
                    name
                    and isinstance(lat, (int, float))
                    and isinstance(lng, (int, float))
                ):
                    key = _normalize_key(name)
                    if key not in _local_points:
                        _local_points[key] = (float(lat), float(lng))
        except Exception as exc:
            logger.debug("Local geocoder points skipped for %s: %s", file_path, exc)


def _lookup_local_point(
    address: str, *, allow_fuzzy: bool = True
) -> tuple[float, float] | None:
    _load_local_points()
    normalized = _normalize_key(address)
    if normalized in _local_points:
        return _local_points[normalized]

    # Check clean address variants
    clean_addr = re.sub(r"^(г\.|город|г\s)\s*нижневартовск\s*,?\s*", "", normalized).strip()
    clean_addr = re.sub(r"^(ул\.|улица)\s*", "", clean_addr).strip()
    if clean_addr in _local_points:
        return _local_points[clean_addr]

    # Do not allow loose camera substring matching if address contains a house number
    has_house_number = bool(re.search(r"\d+", normalized))
    if not allow_fuzzy or has_house_number:
        return None

    for key, coords in _local_points.items():
        if key == normalized:
            return coords
    return None


def _lookup_from_reports(address: str) -> tuple[float, float] | None:
    db = SessionLocal()
    try:
        normalized = address.strip()
        report = (
            db.query(Report)
            .filter(
                Report.address == normalized,
                Report.lat.isnot(None),
                Report.lng.isnot(None),
            )
            .order_by(Report.updated_at.desc())
            .first()
        )
        if report and report.lat is not None and report.lng is not None:
            return float(report.lat), float(report.lng)
    except Exception as exc:
        logger.debug("Local report geo lookup failed: %s", exc)
    finally:
        db.close()
    return None


def _clean_source_text(text: str) -> str:
    cleaned = text.replace("\n", " ")
    cleaned = re.sub(r"https?://\S+", " ", cleaned)
    cleaned = re.sub(r"[@#][\w\-.]+", " ", cleaned)
    cleaned = re.sub(r"[|<>«»\"“”]", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def _compact_address_token(value: str) -> str:
    return re.sub(r"[\s\-.,]+", "", value.strip().lower())


def _normalize_street_token(value: str) -> str:
    normalized = _normalize_key(value)
    normalized = normalized.replace("куропаткина", "кузоваткина")
    normalized = re.sub(
        r"\b(ул|улица|пр|проспект|пер|переулок|б-р|бульвар|мкр|микрорайон|дом|д)\.?\b",
        " ",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r"[^0-9a-zа-яё]+", " ", normalized, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", normalized).strip()


def _has_street_type_prefix(lower_name: str) -> bool:
    prefixes = [
        "ул", "улица", "пр", "проспект", "пр-кт", "пр-т", "пер", "переулок",
        "б-р", "бульвар", "мкр", "микрорайон", "поселок", "посёлок", "пос",
        "проезд", "шоссе", "тракт", "квартал", "аллея", "площадь", "пл",
        "сквер", "сонт", "снт", "днт", "гп"
    ]
    return any(re.search(rf"\b{p}\b\.?", lower_name) for p in prefixes)


def _extract_house_number(value: str) -> str | None:
    match = re.search(
        r"\b(\d{1,4}[a-zа-яё]?(?:/\d+[a-zа-яё]?)?)\b", value, re.IGNORECASE
    )
    if not match:
        return None
    return _compact_address_token(match.group(1))


def _parse_expected_address(address: str) -> tuple[str | None, str | None]:
    normalized = sanitize_address_candidate(address) or _clean_source_text(address)
    if not normalized:
        return None, None

    house_match = re.search(
        r"\b(\d{1,4}[a-zа-яё]?(?:/\d+[a-zа-яё]?)?)\b",
        normalized,
        re.IGNORECASE,
    )
    house = _compact_address_token(house_match.group(1)) if house_match else None

    street_source = normalized
    if house_match:
        street_source = normalized[: house_match.start()]
    street_source = street_source.split(",", 1)[0]
    if CITY_NAME:
        street_source = re.sub(
            re.escape(CITY_NAME),
            " ",
            street_source,
            flags=re.IGNORECASE,
        )

    street = _normalize_street_token(street_source)
    return (street or None), (house or None)


def _extract_candidate_streets(result: dict[str, Any]) -> list[str]:
    address = result.get("address")
    values: list[str] = []
    if isinstance(address, dict):
        for field in (
            "road",
            "street",
            "pedestrian",
            "residential",
            "quarter",
            "neighbourhood",
            "hamlet",
        ):
            value = address.get(field)
            if isinstance(value, str) and value.strip():
                values.append(value)

    for field in ("name", "display_name"):
        value = result.get(field)
        if isinstance(value, str) and value.strip():
            values.append(value)
    return values


def _extract_candidate_house_numbers(result: dict[str, Any]) -> list[str]:
    address = result.get("address")
    values: list[str] = []
    if isinstance(address, dict):
        house_number = address.get("house_number")
        if isinstance(house_number, str) and house_number.strip():
            values.append(house_number)

    for field in ("name", "display_name"):
        value = result.get(field)
        if isinstance(value, str) and value.strip():
            extracted = _extract_house_number(value)
            if extracted:
                values.append(extracted)
    return values


def _street_matches(expected_street: str | None, result: dict[str, Any]) -> bool:
    if not expected_street:
        return True
    for candidate in _extract_candidate_streets(result):
        normalized_candidate = _normalize_street_token(candidate)
        if not normalized_candidate:
            continue
        if "\uFFFD" in normalized_candidate:
            return True
        if (
            normalized_candidate == expected_street
            or expected_street in normalized_candidate
            or normalized_candidate in expected_street
        ):
            return True
    return False


def _house_matches(expected_house: str | None, result: dict[str, Any]) -> bool:
    if not expected_house:
        return True
    for candidate in _extract_candidate_house_numbers(result):
        normalized_candidate = (
            candidate
            if candidate == _compact_address_token(candidate)
            else _compact_address_token(candidate)
        )
        if normalized_candidate == expected_house:
            return True
    return False


def _pick_best_result(
    items: list[dict[str, Any]],
    *,
    expected_street: str | None,
    expected_house: str | None,
) -> dict[str, Any] | None:
    # Handle intersection address queries (e.g. перекрёсток Мира и Чапаева)
    if expected_street and ("перекресток" in expected_street or "перекрёсток" in expected_street):
        parts = re.split(r"\b(?:и|&)\b", expected_street)
        streets_to_match = []
        for p in parts:
            p_clean = re.sub(r"перекр[её]сток|нижневартовск", "", p).strip()
            if p_clean:
                streets_to_match.append(p_clean)
        if streets_to_match:
            for item in items:
                for cand in _extract_candidate_streets(item):
                    cand_norm = _normalize_street_token(cand)
                    if any(s in cand_norm or cand_norm in s for s in streets_to_match):
                        return item
            return items[0] if items else None

    exact_matches = [
        item
        for item in items
        if _street_matches(expected_street, item)
        and _house_matches(expected_house, item)
    ]
    if exact_matches:
        return exact_matches[0]

    if expected_house:
        return None

    street_matches = [item for item in items if _street_matches(expected_street, item)]
    if street_matches:
        return street_matches[0]

    return items[0] if items else None


def _looks_like_street_name(value: str) -> bool:
    normalized = _normalize_key(value)
    if not normalized or normalized in _STOPWORDS:
        return False
    if normalized in NV_STREET_HINTS:
        return True
    if "лет октября" in normalized or "дружбы народов" in normalized:
        return True
    return len(normalized) >= 4 and re.search(r"[а-яё]", normalized) is not None


def extract_address_from_text(text: str) -> str | None:
    cleaned = _clean_source_text(text)
    if not cleaned:
        return None

    intersection_patterns = [
        r"перекр[её]ст(?:ок|ке)\s+(?:ул(?:ица|\.?)\s*)?([А-Яа-яЁё0-9\-\s]+?)\s+и\s+(?:ул(?:ица|\.?)\s*)?([А-Яа-яЁё0-9\-\s]+?)(?:[,.]|$)",
        r"(?:на\s+)?угл[уе]\s+(?:ул(?:ица|\.?)\s*)?([А-Яа-яЁё0-9\-\s]+?)\s+и\s+(?:ул(?:ица|\.?)\s*)?([А-Яа-яЁё0-9\-\s]+?)(?:[,.]|$)",
        r"(?:ул(?:ица|\.?)\s*)?([А-Яа-яЁё0-9\-\s]+?)\s*/\s*(?:ул(?:ица|\.?)\s*)?([А-Яа-яЁё0-9\-\s]+?)(?:[,.]|$)",
    ]
    for pattern in intersection_patterns:
        match = re.search(pattern, cleaned, re.IGNORECASE)
        if not match:
            continue
        street1 = match.group(1).strip(" ,.")
        street2 = match.group(2).strip(" ,.")
        if _looks_like_street_name(street1) and _looks_like_street_name(street2):
            return f"перекрёсток ул. {street1} и ул. {street2}, {CITY_NAME}"

    address_patterns = [
        (
            r"(?:\bул(?:иц[аеыу])?\.?\s*)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "ул.",
        ),
        (
            r"(?:\bпроезд\s+)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "проезд",
        ),
        (
            r"(?:\bпр(?:оспект[аеу]?)?\.?\s*)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "пр.",
        ),
        (
            r"(?:\bпер(?:еулок)?\.?\s*)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "пер.",
        ),
        (
            r"(?:\bб(?:ульвар|-р)\b\.?\s*)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "б-р",
        ),
        (
            r"(?:\bмкр\b|\bмикрорайон\b)\s*([0-9]+[А-Яа-я]?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "мкр.",
        ),
    ]

    for pattern, prefix in address_patterns:
        match = re.search(pattern, cleaned, re.IGNORECASE)
        if not match:
            continue
        street = match.group(1).strip(" ,.")
        house = match.group(2).strip(" ,.")
        if not _looks_like_street_name(street):
            continue
        return f"{prefix} {street} {house}, {CITY_NAME}"

    contextual_match = re.search(
        r"(?:на|по|у|возле|около|напротив)\s+([А-Яа-яЁё0-9\-\s]+?)\s+(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)\b",
        cleaned,
        re.IGNORECASE,
    )
    if contextual_match:
        street = contextual_match.group(1).strip(" ,.")
        house = contextual_match.group(2).strip(" ,.")
        if _looks_like_street_name(street):
            return f"ул. {street} {house}, {CITY_NAME}"

    return None


def sanitize_address_candidate(address: str | None) -> str | None:
    """Normalize a candidate address and drop obviously broken public-parser garbage."""
    if not address:
        return None

    cleaned = _clean_source_text(address)
    if not cleaned:
        return None

    normalized = _normalize_key(cleaned)

    # Re-parse structured addresses and freeform fragments into a consistent city-local form.
    reparsed = extract_address_from_text(cleaned)
    if reparsed:
        return reparsed

    landmark = find_landmark(cleaned)
    if landmark:
        name, _, _ = landmark
        return f"район {name}, {CITY_NAME}"

    normalized = _normalize_key(cleaned)
    if len(normalized) > 120:
        return None

    tokens = [token for token in re.split(r"[\s,.;:()]+", normalized) if token]
    if not tokens:
        return None

    leading_stopwords = sum(1 for token in tokens[:3] if token in _STOPWORDS)
    has_house_number = (
        re.search(r"\b\d{1,3}[а-яa-z]?(?:/\d+)?\b", normalized) is not None
    )
    has_street_marker = any(
        marker in normalized
        for marker in (
            "ул",
            "улица",
            "проспект",
            "пр.",
            "пер",
            "переулок",
            "бульвар",
            "б-р",
            "мкр",
            "микрорайон",
        )
    )
    has_known_street = any(hint in normalized for hint in NV_STREET_HINTS)

    if leading_stopwords >= 1 and not has_street_marker:
        return None
    if has_house_number and not (has_street_marker or has_known_street):
        return None
    if len(tokens) > 8 and not has_street_marker:
        return None

    if CITY_NAME.lower() in normalized and (has_street_marker or has_known_street):
        return cleaned
    if has_street_marker or has_known_street:
        return f"{cleaned}, {CITY_NAME}"
    if normalized.startswith("gps ") and CITY_NAME.lower() in normalized:
        return cleaned
    return None


def _coords_belong_to_city(coords: tuple[float, float], city: str | None) -> bool:
    """Проверяет, что координаты внутри viewbox именно запрошенного города
    (защита от матча «ул. Ленина» в чужом городе)."""
    try:
        vb = [float(x) for x in _viewbox_for_city(city).split(",")]
        min_lon, min_lat, max_lon, max_lat = vb
        return min_lat <= float(coords[0]) <= max_lat and min_lon <= float(coords[1]) <= max_lon
    except (TypeError, ValueError, IndexError):
        return True


def is_coords_in_city(lat: float, lon: float) -> bool:
    try:
        # Check Nizhnevartovsk viewbox
        nv_min_lon, nv_min_lat, nv_max_lon, nv_max_lat = 76.42, 60.85, 76.70, 61.02
        if nv_min_lat <= float(lat) <= nv_max_lat and nv_min_lon <= float(lon) <= nv_max_lon:
            return True
        return False
    except (TypeError, ValueError):
        return True


def format_gps_fallback_address(lat: float, lon: float) -> str:
    return f"GPS {float(lat):.5f}, {float(lon):.5f}, {CITY_NAME}"


def is_street_level_address(address: str | None) -> bool:
    if not address or not str(address).strip():
        return False
    normalized = _normalize_key(str(address))
    if normalized.startswith("gps "):
        return True
    has_street_marker = any(
        marker in normalized
        for marker in (
            "ул",
            "улица",
            "проспект",
            "пр.",
            "пер",
            "переулок",
            "бульвар",
            "б-р",
            "мкр",
            "микрорайон",
            "район",
        )
    )
    has_known_street = any(hint in normalized for hint in NV_STREET_HINTS)
    return has_street_marker or has_known_street


async def resolve_address_from_coords(
    lat: float,
    lon: float,
    *,
    existing: str | None = None,
) -> str:
    """Best-effort address for map markers: reverse geocode or GPS label."""
    normalized_existing = sanitize_address_candidate(existing)
    if normalized_existing:
        return normalized_existing

    rev = await reverse_geocode(float(lat), float(lon))
    if rev:
        cleaned = sanitize_address_candidate(rev)
        if cleaned:
            return cleaned
        if is_street_level_address(rev):
            return rev.strip()

    return format_gps_fallback_address(lat, lon)


def find_landmark(text: str) -> tuple[str, float, float] | None:
    cleaned = _normalize_key(_clean_source_text(text))
    for name, (lat, lon) in NV_LANDMARKS.items():
        if _normalize_key(name) in cleaned:
            return name, lat, lon
    return None


def _build_queries(address: str, city: str = "nizhnevartovsk") -> list[str]:
    cleaned = re.sub(r"\s+", " ", address.strip(" ,"))
    if not cleaned:
        return []
    
    city_name_str = "Нижневартовск"  # приложение работает только с Нижневартовском
    
    # Check for intersection patterns in clean address
    intersection_match = re.search(
        r"(?:перекр[её]ст(?:ок|ке)|угол|угл[уе])?\s*(?:\b(ул(?:ица)?\.?|пр(?:оспект)?\.?|b-r|бульвар|пер(?:еулок)?\.?|проезд)\s+)?([А-Яа-яЁё0-9\-\s]+?)\s+(?:и|/|&|пересечение\s+с)\s*(?:\b(ул(?:ица)?\.?|пр(?:оспект)?\.?|b-r|бульвар|пер(?:еулок)?\.?|проезд)\s+)?([А-Яа-яЁё0-9\-\s]+?)(?:,|$)",
        cleaned,
        re.IGNORECASE
    )
    if intersection_match:
        pref1 = intersection_match.group(1) or "ул."
        street1 = intersection_match.group(2).strip()
        pref2 = intersection_match.group(3) or "ул."
        street2 = intersection_match.group(4).strip()
        if len(street1) >= 3 and len(street2) >= 3:
            q = f"{pref1} {street1} & {pref2} {street2}, {city_name_str}"
            return [q]

    if city_name_str.lower() in cleaned.lower():
        return [cleaned]
    return [f"{cleaned}, {city_name_str}", f"{city_name_str}, {cleaned}"]


async def _request_json(url: str) -> Any:
    global _geo_semaphore
    if _geo_semaphore is None:
        _geo_semaphore = asyncio.Semaphore(3)
        
    async with _geo_semaphore:
        client = get_client()
        last_error: Exception | None = None
        for attempt in range(GEO_MAX_RETRIES + 1):
            try:
                response = await client.get(
                    url,
                    headers={"User-Agent": "SoobshioGeo/2.0"},
                )
                response.raise_for_status()
                return response.json()
            except (
                httpx.TimeoutException,
                httpx.ConnectError,
                httpx.HTTPStatusError,
            ) as exc:
                last_error = exc
                if attempt >= GEO_MAX_RETRIES:
                    break
                await asyncio.sleep(GEO_RETRY_DELAY * (attempt + 1))
        if last_error:
            raise last_error
    return None


_CITY_VIEWBOXES = {
    "nizhnevartovsk": CITY_VIEWBOX,
}


def _viewbox_for_city(city: str | None) -> str:
    return _CITY_VIEWBOXES.get((city or "").strip().lower(), CITY_VIEWBOX)


async def _query_nominatim(
    query: str,
    *,
    expected_street: str | None = None,
    expected_house: str | None = None,
    city: str = "nizhnevartovsk",
) -> tuple[float, float] | None:
    url = (
        "https://nominatim.openstreetmap.org/search"
        f"?q={quote(query)}"
        "&format=jsonv2&limit=5&addressdetails=1&countrycodes=ru"
        f"&viewbox={_viewbox_for_city(city)}&bounded=0"
    )
    try:
        data = await _request_json(url)
        if isinstance(data, list) and data:
            best_match = _pick_best_result(
                [item for item in data if isinstance(item, dict)],
                expected_street=expected_street,
                expected_house=expected_house,
            )
            if best_match:
                return float(best_match["lat"]), float(best_match["lon"])
    except Exception as exc:
        logger.debug("Nominatim geocode failed for %s: %s", query, exc)
    return None


async def _query_photon(
    query: str,
    *,
    expected_street: str | None = None,
    expected_house: str | None = None,
) -> tuple[float, float] | None:
    url = (
        "https://photon.komoot.io/api/"
        f"?q={quote(query)}&limit=5"
        f"&lat={CITY_CENTER[0]}&lon={CITY_CENTER[1]}"
    )
    try:
        data = await _request_json(url)
        features = data.get("features") if isinstance(data, dict) else None
        if isinstance(features, list) and features:
            candidates: list[dict[str, Any]] = []
            for feature in features:
                if not isinstance(feature, dict):
                    continue
                properties = feature.get("properties")
                geometry = feature.get("geometry")
                if not isinstance(properties, dict) or not isinstance(geometry, dict):
                    continue
                coords = geometry.get("coordinates")
                if not isinstance(coords, list) or len(coords) < 2:
                    continue
                candidate = {
                    "lat": coords[1],
                    "lon": coords[0],
                    "name": properties.get("name"),
                    "display_name": ", ".join(
                        str(item).strip()
                        for item in (
                            properties.get("street"),
                            properties.get("housenumber"),
                            properties.get("city"),
                        )
                        if str(item or "").strip()
                    ),
                    "address": {
                        "road": properties.get("street"),
                        "house_number": properties.get("housenumber"),
                    },
                }
                candidates.append(candidate)

            best_match = _pick_best_result(
                candidates,
                expected_street=expected_street,
                expected_house=expected_house,
            )
            if best_match:
                return float(best_match["lat"]), float(best_match["lon"])
    except Exception as exc:
        logger.debug("Photon geocode failed for %s: %s", query, exc)
    return None


async def get_coordinates(address: str, local_only: bool = False, city: str = "nizhnevartovsk") -> tuple[float, float] | None:
    if not address or not address.strip():
        return None

    effective_address = sanitize_address_candidate(address) or address.strip()

    expected_street, expected_house = _parse_expected_address(effective_address)

    _ensure_geo_cache_loaded()
    normalized_key = _normalize_key(effective_address)
    if normalized_key in _geo_cache:
        coords = _geo_cache[normalized_key]
        if is_coords_in_city(coords[0], coords[1]) and coords != (0.0, 0.0):
            return coords

    local_point = _lookup_local_point(
        effective_address,
        allow_fuzzy=expected_house is None,
    )
    if local_point:
        return _remember_coordinates(effective_address, local_point)

    if expected_house is None:
        from_reports = _lookup_from_reports(effective_address)
        if from_reports:
            return _remember_coordinates(effective_address, from_reports)

    # Ориентир — только если в адресе НЕТ номера дома: иначе «ул. Героев
    # Самотлора 20» ложится на точку ориентира «самотлор» в 3 км от дома.
    if expected_house is None:
        landmark = find_landmark(effective_address)
        if landmark:
            _, lat, lon = landmark
            return _remember_coordinates(effective_address, (lat, lon))

    if local_only:
        return None

    queries = _build_queries(effective_address, city=city)
    for query in queries:
        if GEO_ENABLE_PHOTON:
            coords = await _query_photon(
                query,
                expected_street=expected_street,
                expected_house=expected_house,
            )
            if coords and _coords_belong_to_city(coords, city):
                return _remember_coordinates(effective_address, coords)

        coords = await _query_nominatim(
            query,
            expected_street=expected_street,
            expected_house=expected_house,
            city=city,
        )
        if coords and _coords_belong_to_city(coords, city):
            return _remember_coordinates(effective_address, coords)

    # Офлайн-фолбэк: локальная база домов (приблизительная сетка, расходится
    # с OSM на 0.5–2 км — используем только если онлайн-геокодеры недоступны)
    if city == "nizhnevartovsk":
        try:
            from services.Backend.comprehensive_marker_geofix import load_knowledge_base, resolve_exact_coords
            houses_kb, inst_kb, street_kb = load_knowledge_base()
            (lat, lng), src = resolve_exact_coords(effective_address, "", "", houses_kb, inst_kb, street_kb)
            if src != "city_center_default" and is_coords_in_city(lat, lng):
                logger.info("Geo offline-fallback (local KB, approximate) for %s [%s]", effective_address, src)
                return (lat, lng)
        except Exception as exc:
            logger.debug("Comprehensive geofix resolution failed for %s: %s", effective_address, exc)

    # Cache failed lookup as (0.0, 0.0) to avoid repeating slow HTTP queries
    _ensure_geo_cache_loaded()
    _geo_cache[normalized_key] = (0.0, 0.0)
    _persist_geo_cache()

    return None


def make_street_view_url(lat: float, lon: float) -> str:
    return (
        "https://www.google.com/maps/@?api=1&map_action=pano"
        f"&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"
    )


def make_map_url(lat: float, lon: float, zoom: int = 15) -> str:
    return (
        f"https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map={zoom}/{lat}/{lon}"
    )


def _reverse_coord_key(lat: float, lon: float) -> str:
    return f"{round(float(lat), 4)}:{round(float(lon), 4)}"


def _ensure_reverse_cache_loaded() -> None:
    global _reverse_cache_loaded
    if _reverse_cache_loaded:
        return
    _reverse_cache_loaded = True
    try:
        if _REVERSE_CACHE_PATH.exists():
            payload = json.loads(_REVERSE_CACHE_PATH.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                _reverse_cache.update({str(k): str(v) for k, v in payload.items()})
    except Exception as exc:
        logger.debug("Reverse geocode cache load failed: %s", exc)


def _persist_reverse_cache() -> None:
    try:
        _REVERSE_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        _REVERSE_CACHE_PATH.write_text(
            json.dumps(_reverse_cache, ensure_ascii=False, indent=0),
            encoding="utf-8",
        )
    except Exception as exc:
        logger.debug("Reverse geocode cache persist failed: %s", exc)


def _remember_reverse_address(lat: float, lon: float, address: str) -> str:
    key = _reverse_coord_key(lat, lon)
    _ensure_reverse_cache_loaded()
    _reverse_cache[key] = address
    _persist_reverse_cache()
    try:
        from services.data_layer.models import GeocodingCache
        db = SessionLocal()
        try:
            existing = db.query(GeocodingCache).filter(GeocodingCache.coord_key == key).first()
            if not existing:
                db.add(GeocodingCache(coord_key=key, address=address))
                db.commit()
        finally:
            db.close()
    except Exception as exc:
        logger.warning("Failed to save reverse geocode to SQLite cache: %s", exc)

    try:
        from services.infrastructure.redis_kv import redis_set

        redis_set(f"geo:rev:{key}", address, ttl_seconds=_REVERSE_REDIS_TTL)
    except Exception:
        pass
    return address


def _lookup_reverse_cache(lat: float, lon: float) -> str | None:
    key = _reverse_coord_key(lat, lon)
    try:
        from services.infrastructure.redis_kv import redis_get

        cached = redis_get(f"geo:rev:{key}")
        if cached:
            return cached
    except Exception:
        pass

    try:
        from services.data_layer.models import GeocodingCache
        db = SessionLocal()
        try:
            cached_db = db.query(GeocodingCache).filter(GeocodingCache.coord_key == key).first()
            if cached_db:
                _ensure_reverse_cache_loaded()
                _reverse_cache[key] = cached_db.address
                return cached_db.address
        finally:
            db.close()
    except Exception as exc:
        logger.warning("Failed to query SQLite reverse geocode cache: %s", exc)

    _ensure_reverse_cache_loaded()
    return _reverse_cache.get(key)



async def _query_photon_reverse(lat: float, lon: float) -> str | None:
    url = f"https://photon.komoot.io/reverse?lat={lat}&lon={lon}&lang=ru"
    try:
        data = await _request_json(url)
        features = data.get("features") if isinstance(data, dict) else None
        if not isinstance(features, list) or not features:
            return None
        props = features[0].get("properties") if isinstance(features[0], dict) else None
        if not isinstance(props, dict):
            return None
        road = props.get("street") or props.get("name")
        house = props.get("housenumber")
        if road:
            road_clean = str(road).strip(" ,")
            lower = road_clean.lower()
            if not _has_street_type_prefix(lower):
                road_clean = f"ул. {road_clean}"
            if house:
                return f"{road_clean} {str(house).strip()}, {CITY_NAME}"
            return f"{road_clean}, {CITY_NAME}"
    except Exception as exc:
        logger.debug("Photon reverse failed for %s,%s: %s", lat, lon, exc)
    return None


async def reverse_geocode(lat: float, lon: float) -> str | None:
    cached = _lookup_reverse_cache(lat, lon)
    if cached:
        return cached

    url = (
        "https://nominatim.openstreetmap.org/reverse"
        f"?lat={lat}&lon={lon}&format=jsonv2&addressdetails=1&zoom=18"
    )
    try:
        data = await _request_json(url)
        if isinstance(data, dict):
            formatted = _format_nominatim_reverse(data)
            if formatted:
                resolved = sanitize_address_candidate(formatted) or formatted
                return _remember_reverse_address(lat, lon, resolved)
            display = data.get("display_name")
            if isinstance(display, str) and display.strip():
                extracted = extract_address_from_text(display)
                if extracted:
                    return _remember_reverse_address(lat, lon, extracted)
                resolved = sanitize_address_candidate(display) or display.strip()
                return _remember_reverse_address(lat, lon, resolved)
    except Exception as exc:
        logger.debug("Reverse geocode failed for %s,%s: %s", lat, lon, exc)

    photon = await _query_photon_reverse(lat, lon)
    if photon:
        resolved = sanitize_address_candidate(photon) or photon
        return _remember_reverse_address(lat, lon, resolved)
    return None


def _format_nominatim_reverse(data: dict[str, Any]) -> str | None:
    """Build a short Nizhnevartovsk street address from Nominatim jsonv2."""
    addr = data.get("address")
    if not isinstance(addr, dict):
        return None

    road = (
        addr.get("road")
        or addr.get("pedestrian")
        or addr.get("residential")
        or addr.get("footway")
        or addr.get("street")
    )
    house = addr.get("house_number") or addr.get("building")
    if road:
        road_clean = str(road).strip(" ,")
        lower = road_clean.lower()
        has_prefix = _has_street_type_prefix(lower)
        if not has_prefix:
            road_clean = f"ул. {road_clean}"
        if house:
            return f"{road_clean} {str(house).strip()}, {CITY_NAME}"
        return f"{road_clean}, {CITY_NAME}"

    suburb = (
        addr.get("suburb")
        or addr.get("neighbourhood")
        or addr.get("quarter")
        or addr.get("city_district")
    )
    if suburb:
        return f"район {str(suburb).strip()}, {CITY_NAME}"

    return None


def close_geo_client() -> None:
    global _client
    _client = None


def get_coordinates_sync(address: str, city: str = "nizhnevartovsk") -> tuple[float, float] | None:
    if not address or not address.strip():
        return None

    effective_address = sanitize_address_candidate(address) or address.strip()
    expected_street, expected_house = _parse_expected_address(effective_address)

    _ensure_geo_cache_loaded()
    normalized_key = _normalize_key(effective_address)
    if normalized_key in _geo_cache:
        coords = _geo_cache[normalized_key]
        if coords != (0.0, 0.0) and _coords_belong_to_city(coords, city):
            return coords
        return None

    local_point = _lookup_local_point(
        effective_address,
        allow_fuzzy=expected_house is None,
    )
    if local_point:
        return _remember_coordinates(effective_address, local_point)

    if expected_house is None:
        from_reports = _lookup_from_reports(effective_address)
        if from_reports:
            return _remember_coordinates(effective_address, from_reports)

    queries = _build_queries(effective_address, city=city)
    headers = {"User-Agent": "SoobshioGeo/2.0"}
    for query in queries:
        try:
            nominatim_url = (
                "https://nominatim.openstreetmap.org/search"
                f"?q={quote(query)}&format=jsonv2&limit=5&addressdetails=1&countrycodes=ru"
                f"&viewbox={_viewbox_for_city(city)}&bounded=0"
            )
            response = httpx.get(nominatim_url, headers=headers, timeout=8)
            if 200 <= response.status_code < 400:
                data = response.json()
                if data:
                    best_match = _pick_best_result(
                        [item for item in data if isinstance(item, dict)],
                        expected_street=expected_street,
                        expected_house=expected_house,
                    )
                    if best_match:
                        coords = float(best_match["lat"]), float(best_match["lon"])
                        if _coords_belong_to_city(coords, city):
                            return _remember_coordinates(effective_address, coords)
        except Exception:
            pass

        try:
            photon_url = (
                "https://photon.komoot.io/api/"
                f"?q={quote(query)}&limit=5&lang=ru"
                f"&lat={CITY_CENTER[0]}&lon={CITY_CENTER[1]}"
            )
            response = httpx.get(photon_url, headers=headers, timeout=8)
            if 200 <= response.status_code < 400:
                data = response.json()
                features = data.get("features") if isinstance(data, dict) else None
                if isinstance(features, list) and features:
                    candidates: list[dict[str, Any]] = []
                    for feature in features:
                        if not isinstance(feature, dict):
                            continue
                        properties = feature.get("properties")
                        geometry = feature.get("geometry")
                        if not isinstance(properties, dict) or not isinstance(
                            geometry, dict
                        ):
                            continue
                        coords_list = geometry.get("coordinates")
                        if not isinstance(coords_list, list) or len(coords_list) < 2:
                            continue
                        candidates.append(
                            {
                                "lat": coords_list[1],
                                "lon": coords_list[0],
                                "name": properties.get("name"),
                                "display_name": ", ".join(
                                    str(item).strip()
                                    for item in (
                                        properties.get("street"),
                                        properties.get("housenumber"),
                                        properties.get("city"),
                                    )
                                    if str(item or "").strip()
                                ),
                                "address": {
                                    "road": properties.get("street"),
                                    "house_number": properties.get("housenumber"),
                                },
                            }
                        )

                    best_match = _pick_best_result(
                        candidates,
                        expected_street=expected_street,
                        expected_house=expected_house,
                    )
                    if best_match:
                        coords = float(best_match["lat"]), float(best_match["lon"])
                        if _coords_belong_to_city(coords, city):
                            return _remember_coordinates(effective_address, coords)
        except Exception:
            pass

    landmark = find_landmark(effective_address)
    if landmark:
        _, lat, lon = landmark
        return lat, lon
    return None


async def geoparse(
    text: str,
    ai_address: str | None = None,
    location_hints: str | None = None,
    city: str = "nizhnevartovsk",
) -> dict[str, Any]:
    result = {"address": None, "lat": None, "lng": None, "geo_source": None}

    candidates: list[tuple[str, str]] = []
    parsed_from_text = extract_address_from_text(text)
    if parsed_from_text:
        candidates.append((parsed_from_text, "text_parser"))

    if ai_address and ai_address.strip() and ai_address.strip().lower() != "null":
        candidates.append((ai_address.strip(), "ai_confident"))

    if location_hints and location_hints.strip():
        candidates.append((location_hints.strip(), "location_hints"))

    seen: set[str] = set()
    for address, source in candidates:
        key = _normalize_key(address)
        if key in seen:
            continue
        seen.add(key)
        coords = await get_coordinates(address, city=city)
        if coords:
            result["address"] = address
            result["lat"], result["lng"] = coords
            result["geo_source"] = source
            return result

    landmark = find_landmark(text)
    if landmark:
        name, lat, lon = landmark
        result["address"] = f"район {name}, {CITY_NAME}"
        result["lat"] = lat
        result["lng"] = lon
        result["geo_source"] = f"landmark:{name}"
        return result

    return result
