# services/uk_service.py
"""
Определение управляющей компании по координатам/адресу.
Данные из opendata_full.json (датасет listoumd — 42 УК Нижневартовска).
"""

import html
import json
import logging
import os
import re
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

_ROOT_DIR = Path(__file__).resolve().parent.parent
_PROJECT_ROOT = _ROOT_DIR.parent
DATA_FILE_CANDIDATES = [
    Path(os.getenv("UK_DATA_FILE", "")).expanduser()
    if os.getenv("UK_DATA_FILE")
    else None,
    _PROJECT_ROOT / "data" / "uk_catalog.json",
    _ROOT_DIR / "data" / "uk_catalog.json",
    _PROJECT_ROOT / "opendata_full.json",
]

# Кэш УК в памяти
_uk_data: list[dict[str, Any]] = []


def _normalize_uk_rows(raw_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Group flat opendata rows and normalize field names."""
    grouped: dict[str, dict[str, Any]] = {}
    streets: dict[str, dict[str, list[str]]] = {}

    for row in raw_rows:
        if not isinstance(row, dict):
            continue
        key = str(row.get("GID") or row.get("INN") or row.get("TITLESM") or row.get("TITLE") or "")
        if not key:
            continue
        if key not in grouped:
            grouped[key] = dict(row)
            streets[key] = {}

        mkd = row.get("MKD")
        if isinstance(mkd, str) and mkd.strip():
            s = mkd.strip()
            if s not in streets[key]:
                streets[key][s] = []
        elif isinstance(mkd, list):
            for block in mkd:
                if isinstance(block, dict):
                    s = str(block.get("STREET") or "").strip()
                    b = block.get("BUILDINGS") or []
                    if s:
                        if s not in streets[key]:
                            streets[key][s] = list(b)
                        else:
                            streets[key][s] = list(set(streets[key][s] + list(b)))
                elif isinstance(block, str) and block.strip():
                    s = block.strip()
                    if s not in streets[key]:
                        streets[key][s] = []

    result: list[dict[str, Any]] = []
    for key, uk in grouped.items():
        uk["MKD"] = [{"STREET": s, "BUILDINGS": b} for s, b in sorted(streets[key].items())]
        if uk.get("ADDRESS") and not uk.get("ADR"):
            uk["ADR"] = uk["ADDRESS"]
        if uk.get("WORK") and not uk.get("WORK_TIME"):
            uk["WORK_TIME"] = uk["WORK"]
        try:
            uk["CNT"] = int(str(uk.get("CNT") or "0").split()[0])
        except (TypeError, ValueError):
            uk["CNT"] = sum(len(b) for b in streets[key].values())
        result.append(uk)
    return result


def _load_uk_data() -> list[dict[str, Any]]:
    """Загружает данные УК из opendata_full.json"""
    global _uk_data
    if _uk_data:
        return _uk_data
    try:
        for candidate in DATA_FILE_CANDIDATES:
            if candidate is None:
                continue
            file_path = Path(candidate)
            if not file_path.exists():
                continue
            with open(file_path, encoding="utf-8") as f:
                data = json.load(f)
            rows = (
                data.get("listoumd", {}).get("rows", [])
                if isinstance(data, dict)
                else data
            )
            if isinstance(rows, list) and rows:
                _uk_data = _normalize_uk_rows(rows)
                logger.info("Loaded %d UK companies from %s", len(_uk_data), file_path)
                return _uk_data
        logger.warning("UK data catalog not found in configured locations")
        return []
    except Exception as e:
        logger.error(f"UK data load error: {e}")
        return []


def _normalize_street(street: str) -> str:
    """Нормализует название улицы для сравнения"""
    s = street.lower().strip()
    # Убираем типы улиц
    for prefix in [
        "улица ",
        "ул. ",
        "ул ",
        "проспект ",
        "пр. ",
        "пр-т ",
        "бульвар ",
        "б-р ",
        "проезд ",
        "переулок ",
        "пер. ",
    ]:
        if s.startswith(prefix):
            s = s[len(prefix) :]
    # Убираем лишние пробелы
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _normalize_building(building: str) -> str:
    """Нормализует номер дома"""
    b = building.lower().strip()
    b = re.sub(r"\s+", "", b)
    # "корп." → "/"
    b = re.sub(r"корп\.?\s*", "/", b)
    return b


def _extract_street_and_building(address: str) -> tuple[str | None, str | None]:
    """Извлекает улицу и номер дома из адреса"""
    addr = address.strip()

    # Специальный паттерн для "60 лет Октября" и подобных числовых улиц
    m = re.search(
        r"(?:ул(?:ица)?\.?\s+)?(\d+\s+лет\s+[А-Яа-яёЁ]+)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я/]*)",
        addr,
        re.IGNORECASE,
    )
    if m:
        return m.group(1).strip(), m.group(2).strip()

    # Паттерн: "ул. Мира, д. 10" или "улица Мира 10" или "Мира, 10"
    patterns = [
        r"(?:ул(?:ица)?\.?\s+|пр(?:оспект)?\.?\s+|б(?:ульвар)?\.?\s+|пер(?:еулок)?\.?\s+|проезд\s+)?"
        r"([А-Яа-яёЁ][А-Яа-яёЁ\s\-]+?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я/]*(?:\s*корп\.?\s*\d+)?)",
    ]

    for pat in patterns:
        m = re.search(pat, addr)
        if m:
            street = m.group(1).strip().rstrip(",").strip()
            building = m.group(2).strip()
            if len(street) >= 2:
                return street, building

    return None, None


def find_uk_by_address(address: str) -> dict[str, Any] | None:
    """Находит УК по текстовому адресу (улица + дом).

    При конфликте (дом в списках нескольких УК) выигрывает УК с наибольшим
    числом домов на этой улице, а не первая по порядку каталога.
    Фолбэк «без буквы» (10а→10) применяется только если точного совпадения
    нигде нет — точное совпадение приоритетнее.
    """
    uk_list = _load_uk_data()
    if not uk_list:
        return None

    street, building = _extract_street_and_building(address)
    if not street:
        return None

    norm_street = _normalize_street(street)
    norm_building = _normalize_building(building) if building else None

    # Собираем кандидатов по всем УК, чтобы разрешать конфликты осознанно
    exact_match = None          # точное совпадение номера (включая букву)
    base_num_match = None       # совпадение без буквы (10а → 10)
    street_matches: list[tuple[int, dict, dict]] = []  # (вес, uk, mkd) — фолбэк по улице

    base_num = re.match(r"(\d+)", norm_building) if norm_building else None

    for uk in uk_list:
        for mkd in uk.get("MKD", []):
            mkd_street = _normalize_street(mkd.get("STREET", ""))
            if not (norm_street in mkd_street or mkd_street in norm_street):
                continue
            buildings = mkd.get("BUILDINGS", [])
            street_weight = len(buildings)

            if not norm_building:
                street_matches.append((street_weight, uk, mkd))
                continue

            for b in buildings:
                if _normalize_building(b) == norm_building:
                    exact_match = _format_uk(uk, mkd.get("STREET"), b)
                    break
            if exact_match:
                break

            if base_num:
                for b in buildings:
                    b_num = re.match(r"(\d+)", _normalize_building(b))
                    if b_num and b_num.group(1) == base_num.group(1):
                        if base_num_match is None:
                            base_num_match = _format_uk(uk, mkd.get("STREET"), b)
                        break
        if exact_match:
            break

    if exact_match:
        result = exact_match
    elif base_num_match:
        result = base_num_match
    elif street_matches:
        # Крупнейший управляющий на улице вероятнее обслуживает дом
        street_matches.sort(key=lambda t: t[0], reverse=True)
        _, uk, mkd = street_matches[0]
        result = _format_uk(uk, mkd.get("STREET"))
    else:
        return None

    # Помечаем конфликтные адреса (135 домов в списках 2+ УК из ГИС ЖКХ)
    if norm_building and norm_street:
        b_key = re.sub(r"[^а-я0-9]", "", norm_building)
        key = f"{norm_street}|{b_key}"
        conflicts = _load_address_conflicts()
        entry = conflicts.get(key)
        if entry:
            result = dict(result)
            result["address_conflict"] = True
            result["conflicting_companies"] = entry.get("companies", [])
    return result


def _load_address_conflicts() -> dict[str, Any]:
    """Карта конфликтных адресов (дом в списках нескольких УК).

    Ключ — «улица|дом» (нормализованные). Значение — компании-претенденты
    и приоритетный управляющий (УК с наибольшим портфелем домов).
    """
    global _address_conflicts_cache
    if _address_conflicts_cache is not None:
        return _address_conflicts_cache
    for candidate in (
        _PROJECT_ROOT / "data" / "uk_address_conflicts.json",
        _ROOT_DIR / "data" / "uk_address_conflicts.json",
    ):
        if candidate.exists():
            try:
                _address_conflicts_cache = json.loads(
                    candidate.read_text(encoding="utf-8")
                )
                return _address_conflicts_cache
            except Exception as exc:
                logger.warning("Failed to load address conflicts: %s", exc)
    _address_conflicts_cache = {}
    return _address_conflicts_cache


_address_conflicts_cache: dict[str, Any] | None = None


async def find_uk_by_coords(lat: float, lon: float) -> dict[str, Any] | None:
    """Находит УК по координатам через обратное геокодирование"""
    try:
        from services.geo_service import reverse_geocode

        address = await reverse_geocode(lat, lon)
        if not address:
            return None
        logger.info(f"🏢 Обратное геокодирование: {lat:.4f},{lon:.4f} → {address}")

        # Пробуем найти по полному адресу
        result = find_uk_by_address(address)
        if result:
            result["geocoded_address"] = address
            return result

        # Если не нашли — пробуем извлечь улицу из частей адреса (через запятые)
        parts = [p.strip() for p in address.split(",")]
        for part in parts:
            result = find_uk_by_address(part)
            if result:
                result["geocoded_address"] = address
                return result

        return None
    except Exception as e:
        logger.error(f"UK by coords error: {e}")
        return None


def _format_uk(
    uk: dict[str, Any], street: str = None, building: str = None
) -> dict[str, Any]:
    """Форматирует данные УК для вывода"""
    name = html.unescape(str(uk.get("TITLESM") or uk.get("TITLE", "")).strip())
    houses_count = uk.get("CNT", 0)

    # Try to load rating from DB for this UK
    overall_score = 0.0
    grade = "—"
    total_complaints = 0
    resolved_complaints = 0
    resolve_percent = 0.0
    citizen_score = 0.0
    citizen_votes = 0

    try:
        from services.business.uk_rating_service import get_rating_by_name
        rating = get_rating_by_name(name)
        if rating:
            overall_score = rating.get("overall_score", 0.0)
            grade = rating.get("grade", "—")
            total_complaints = rating.get("total_complaints", 0)
            resolved_complaints = rating.get("resolved_complaints", 0)
            resolve_percent = rating.get("resolve_percent", 0.0)
            citizen_score = rating.get("citizen_score", 0.0)
            citizen_votes = rating.get("citizen_votes", 0)
    except Exception as e:
        logger.warning("Failed to fetch rating for format_uk: %s", e)

    return {
        "name": name,
        "uk_name": name,
        "full_name": html.unescape(str(uk.get("TITLE", "")).strip()),
        "phone": uk.get("TEL"),
        "email": uk.get("EMAIL"),
        "address": uk.get("ADR"),
        "url": uk.get("URL"),
        "director": uk.get("FIO"),
        "work_time": uk.get("WORK_TIME"),
        "houses_count": houses_count,
        "houses": houses_count,
        "matched_street": street,
        "matched_building": building,
        "overall_score": overall_score,
        "grade": grade,
        "total_complaints": total_complaints,
        "resolved_complaints": resolved_complaints,
        "resolve_percent": resolve_percent,
        "citizen_score": citizen_score,
        "citizen_votes": citizen_votes,
    }



def get_all_uk_emails() -> list[dict[str, str]]:
    """Возвращает каталог всех УК, не только записей с email."""
    uk_list = _load_uk_data()
    result = []
    for uk in uk_list:
        name = html.unescape((uk.get("TITLESM") or uk.get("TITLE", "")).strip())
        if not name:
            continue
        result.append(
            {
                "name": name,
                "email": uk.get("EMAIL", ""),
                "phone": uk.get("TEL", ""),
                "houses": uk.get("CNT", 0),
            }
        )
    return result


def get_uk_catalog() -> list[dict[str, Any]]:
    """Full UK catalog with contacts, houses and optional ratings."""
    uk_list = _load_uk_data()
    ratings_index: dict[str, dict[str, Any]] = {}
    try:
        from services.business.uk_rating_service import get_all_ratings

        for row in get_all_ratings(limit=200):
            key = html.unescape(str(row.get("uk_name") or "")).strip().lower()
            if key:
                ratings_index[key] = row
    except Exception as exc:
        logger.warning("UK ratings merge skipped: %s", exc)

    catalog: list[dict[str, Any]] = []
    seen: set[str] = set()
    for uk in uk_list:
        name = html.unescape(str(uk.get("TITLESM") or uk.get("TITLE") or "").strip())
        if not name:
            continue
        dedupe_key = str(uk.get("GID") or uk.get("INN") or name).lower()
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        mkd = uk.get("MKD") or []
        streets: set[str] = set()
        for block in mkd:
            if isinstance(block, dict):
                s = str(block.get("STREET") or "").strip()
            elif isinstance(block, str):
                s = block.strip()
            else:
                s = ""
            if s:
                streets.add(s)
        streets_list = sorted(streets)
        buildings_total = sum(
            len(block.get("BUILDINGS") or []) for block in mkd if isinstance(block, dict)
        )
        rating = ratings_index.get(name.lower(), {})
        catalog.append(
            {
                "name": name,
                "full_name": html.unescape(str(uk.get("TITLE") or name).strip()),
                "phone": uk.get("TEL") or "",
                "email": uk.get("EMAIL") or "",
                "address": uk.get("ADR") or uk.get("ADDRESS") or "",
                "url": uk.get("URL") or "",
                "director": uk.get("FIO") or "",
                "work_time": uk.get("WORK_TIME") or uk.get("WORK") or "",
                "houses_count": int(uk.get("CNT") or buildings_total or 0),
                "streets_count": len(streets_list),
                "streets_preview": streets_list[:8],
                "streets": streets_list,
                "buildings_count": buildings_total,
                "mkd": [
                    {
                        "street": block.get("STREET"),
                        "buildings": block.get("BUILDINGS") or [],
                    }
                    for block in mkd
                    if isinstance(block, dict) and block.get("STREET")
                ],
                "overall_score": rating.get("overall_score", 0),
                "grade": rating.get("grade", "—"),
                "total_complaints": rating.get("total_complaints", 0),
                "resolved_complaints": rating.get("resolved_complaints", 0),
                "resolve_percent": rating.get("resolve_percent", 0),
                "citizen_score": rating.get("citizen_score", 0),
                "citizen_votes": rating.get("citizen_votes", 0),
            }
        )

    catalog.sort(
        key=lambda row: (
            float(row.get("overall_score") or 0),
            int(row.get("houses_count") or 0),
        ),
        reverse=True,
    )
    return catalog
