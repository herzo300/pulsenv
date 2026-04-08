import asyncio
import json
import logging
import os
import re
from pathlib import Path
from typing import Any, Optional, Tuple
from urllib.parse import quote

import httpx
import requests

from backend.database import SessionLocal
from backend.models import Report
from core.http_client import get_http_client

logger = logging.getLogger(__name__)

CITY_NAME = os.getenv("GEO_CITY_NAME", "Нижневартовск")
CITY_CENTER = (60.9344, 76.5531)
CITY_VIEWBOX = "76.42,60.85,76.70,61.02"
GEO_MAX_RETRIES = int(os.getenv("GEO_MAX_RETRIES", "2"))
GEO_RETRY_DELAY = float(os.getenv("GEO_RETRY_DELAY", "0.8"))
GEO_CACHE_PATH = Path(os.getenv("GEO_CACHE_PATH", "data/geocode_cache.json"))
GEO_ENABLE_PHOTON = os.getenv("GEO_ENABLE_PHOTON", "false").lower() in {"1", "true", "yes"}

_client: Optional[httpx.AsyncClient] = None
_geo_cache: dict[str, tuple[float, float]] = {}
_geo_cache_loaded = False
_local_points_loaded = False
_local_points: dict[str, tuple[float, float]] = {}

NV_LANDMARKS = {
    "самотлор": (60.9398, 76.5652),
    "озеро комсомольское": (60.9450, 76.5500),
    "комсомольское озеро": (60.9450, 76.5500),
    "сити центр": (60.9380, 76.5530),
    "югра молл": (60.9420, 76.5700),
    "автовокзал": (60.9410, 76.5730),
    "жд вокзал": (60.9560, 76.5850),
    "аэропорт": (60.9490, 76.4880),
    "площадь нефтяников": (60.9370, 76.5530),
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


def _remember_coordinates(address: str, coords: tuple[float, float]) -> tuple[float, float]:
    _ensure_geo_cache_loaded()
    _geo_cache[_normalize_key(address)] = coords
    _persist_geo_cache()
    return coords


def _load_local_points() -> None:
    global _local_points_loaded
    if _local_points_loaded:
        return
    _local_points_loaded = True

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
                if name and isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
                    _local_points[_normalize_key(name)] = (float(lat), float(lng))
        except Exception as exc:
            logger.debug("Local geocoder points skipped for %s: %s", file_path, exc)


def _lookup_local_point(address: str, *, allow_fuzzy: bool = True) -> Optional[tuple[float, float]]:
    _load_local_points()
    normalized = _normalize_key(address)
    if normalized in _local_points:
        return _local_points[normalized]

    if not allow_fuzzy:
        return None

    for key, coords in _local_points.items():
        if normalized in key or key in normalized:
            return coords
    return None


def _lookup_from_reports(address: str) -> Optional[tuple[float, float]]:
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
    normalized = re.sub(
        r"\b(ул|улица|пр|проспект|пер|переулок|б-р|бульвар|мкр|микрорайон|дом|д)\.?\b",
        " ",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r"[^0-9a-zа-яё]+", " ", normalized, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", normalized).strip()


def _extract_house_number(value: str) -> Optional[str]:
    match = re.search(r"\b(\d{1,4}[a-zа-яё]?(?:/\d+[a-zа-яё]?)?)\b", value, re.IGNORECASE)
    if not match:
        return None
    return _compact_address_token(match.group(1))


def _parse_expected_address(address: str) -> tuple[Optional[str], Optional[str]]:
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


def _street_matches(expected_street: Optional[str], result: dict[str, Any]) -> bool:
    if not expected_street:
        return True
    for candidate in _extract_candidate_streets(result):
        normalized_candidate = _normalize_street_token(candidate)
        if not normalized_candidate:
            continue
        if (
            normalized_candidate == expected_street
            or expected_street in normalized_candidate
            or normalized_candidate in expected_street
        ):
            return True
    return False


def _house_matches(expected_house: Optional[str], result: dict[str, Any]) -> bool:
    if not expected_house:
        return True
    for candidate in _extract_candidate_house_numbers(result):
        normalized_candidate = (
            candidate if candidate == _compact_address_token(candidate) else _compact_address_token(candidate)
        )
        if normalized_candidate == expected_house:
            return True
    return False


def _pick_best_result(
    items: list[dict[str, Any]],
    *,
    expected_street: Optional[str],
    expected_house: Optional[str],
) -> Optional[dict[str, Any]]:
    exact_matches = [
        item
        for item in items
        if _street_matches(expected_street, item) and _house_matches(expected_house, item)
    ]
    if exact_matches:
        return exact_matches[0]

    if expected_house:
        return None

    street_matches = [
        item
        for item in items
        if _street_matches(expected_street, item)
    ]
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


def extract_address_from_text(text: str) -> Optional[str]:
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
            r"(?:\bул(?:ица)?\.?\s*)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
            "ул.",
        ),
        (
            r"(?:\bпр(?:оспект)?\.?\s*)([А-Яа-яЁё0-9\-\s]+?)\s*[,.]?\s*(?:дом|д\.?)?\s*(\d{1,3}[А-Яа-яа-я]?(?:/\d+)?)",
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


def sanitize_address_candidate(address: Optional[str]) -> Optional[str]:
    """Normalize a candidate address and drop obviously broken public-parser garbage."""
    if not address:
        return None

    cleaned = _clean_source_text(address)
    if not cleaned:
        return None

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
    has_house_number = re.search(r"\b\d{1,3}[а-яa-z]?(?:/\d+)?\b", normalized) is not None
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
    return None


def find_landmark(text: str) -> Optional[Tuple[str, float, float]]:
    cleaned = _normalize_key(_clean_source_text(text))
    for name, (lat, lon) in NV_LANDMARKS.items():
        if _normalize_key(name) in cleaned:
            return name, lat, lon
    return None


def _build_queries(address: str) -> list[str]:
    cleaned = re.sub(r"\s+", " ", address.strip(" ,"))
    if not cleaned:
        return []
    if CITY_NAME.lower() in cleaned.lower():
        return [cleaned]
    return [f"{cleaned}, {CITY_NAME}", f"{CITY_NAME}, {cleaned}"]


async def _request_json(url: str) -> Any:
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
      except (httpx.TimeoutException, httpx.ConnectError, httpx.HTTPStatusError) as exc:
          last_error = exc
          if attempt >= GEO_MAX_RETRIES:
              break
          await asyncio.sleep(GEO_RETRY_DELAY * (attempt + 1))
    if last_error:
        raise last_error
    return None


async def _query_nominatim(
    query: str,
    *,
    expected_street: Optional[str] = None,
    expected_house: Optional[str] = None,
) -> Optional[tuple[float, float]]:
    url = (
        "https://nominatim.openstreetmap.org/search"
        f"?q={quote(query)}"
        "&format=jsonv2&limit=5&addressdetails=1&countrycodes=ru"
        f"&viewbox={CITY_VIEWBOX}&bounded=0"
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
    expected_street: Optional[str] = None,
    expected_house: Optional[str] = None,
) -> Optional[tuple[float, float]]:
    url = (
        "https://photon.komoot.io/api/"
        f"?q={quote(query)}&limit=5&lang=ru"
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


async def get_coordinates(address: str) -> Optional[Tuple[float, float]]:
    if not address or not address.strip():
        return None

    effective_address = sanitize_address_candidate(address) or address.strip()
    expected_street, expected_house = _parse_expected_address(effective_address)

    _ensure_geo_cache_loaded()
    normalized_key = _normalize_key(effective_address)
    if normalized_key in _geo_cache:
        return _geo_cache[normalized_key]

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

    landmark = find_landmark(effective_address)
    if landmark:
        _, lat, lon = landmark
        return _remember_coordinates(effective_address, (lat, lon))

    queries = _build_queries(effective_address)
    for query in queries:
        coords = await _query_nominatim(
            query,
            expected_street=expected_street,
            expected_house=expected_house,
        )
        if coords:
            return _remember_coordinates(effective_address, coords)

        if GEO_ENABLE_PHOTON:
            coords = await _query_photon(
                query,
                expected_street=expected_street,
                expected_house=expected_house,
            )
            if coords:
                return _remember_coordinates(effective_address, coords)

    return None


def make_street_view_url(lat: float, lon: float) -> str:
    return (
        "https://www.google.com/maps/@?api=1&map_action=pano"
        f"&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"
    )


def make_map_url(lat: float, lon: float, zoom: int = 15) -> str:
    return f"https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map={zoom}/{lat}/{lon}"


async def reverse_geocode(lat: float, lon: float) -> Optional[str]:
    url = (
        "https://nominatim.openstreetmap.org/reverse"
        f"?lat={lat}&lon={lon}&format=jsonv2"
    )
    try:
        data = await _request_json(url)
        if isinstance(data, dict):
            return data.get("display_name")
    except Exception as exc:
        logger.debug("Reverse geocode failed for %s,%s: %s", lat, lon, exc)
    return None


def close_geo_client() -> None:
    global _client
    _client = None


def get_coordinates_sync(address: str) -> Optional[Tuple[float, float]]:
    if not address or not address.strip():
        return None

    effective_address = sanitize_address_candidate(address) or address.strip()
    expected_street, expected_house = _parse_expected_address(effective_address)

    _ensure_geo_cache_loaded()
    normalized_key = _normalize_key(effective_address)
    if normalized_key in _geo_cache:
        return _geo_cache[normalized_key]

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

    queries = _build_queries(effective_address)
    headers = {"User-Agent": "SoobshioGeo/2.0"}
    for query in queries:
        try:
            nominatim_url = (
                "https://nominatim.openstreetmap.org/search"
                f"?q={quote(query)}&format=jsonv2&limit=5&addressdetails=1&countrycodes=ru"
                f"&viewbox={CITY_VIEWBOX}&bounded=0"
            )
            response = requests.get(nominatim_url, headers=headers, timeout=8)
            if response.ok:
                data = response.json()
                if data:
                    best_match = _pick_best_result(
                        [item for item in data if isinstance(item, dict)],
                        expected_street=expected_street,
                        expected_house=expected_house,
                    )
                    if best_match:
                        coords = float(best_match["lat"]), float(best_match["lon"])
                        return _remember_coordinates(effective_address, coords)
        except Exception:
            pass

        try:
            photon_url = (
                "https://photon.komoot.io/api/"
                f"?q={quote(query)}&limit=5&lang=ru"
                f"&lat={CITY_CENTER[0]}&lon={CITY_CENTER[1]}"
            )
            response = requests.get(photon_url, headers=headers, timeout=8)
            if response.ok:
                data = response.json()
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
    ai_address: Optional[str] = None,
    location_hints: Optional[str] = None,
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
        coords = await get_coordinates(address)
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
