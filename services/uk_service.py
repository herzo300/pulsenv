# services/uk_service.py
"""
Определение управляющей компании по координатам/адресу.
Данные из opendata_full.json (датасет listoumd — 42 УК Нижневартовска).
"""

import json
import os
import re
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

logger = logging.getLogger(__name__)

_ROOT_DIR = Path(__file__).resolve().parent.parent
DATA_FILE_CANDIDATES = [
    Path(os.getenv("UK_DATA_FILE", "")).expanduser() if os.getenv("UK_DATA_FILE") else None,
    _ROOT_DIR / "data" / "uk_catalog.json",
    _ROOT_DIR / "opendata_full.json",
]

# Кэш УК в памяти
_uk_data: List[Dict[str, Any]] = []


def _load_uk_data() -> List[Dict[str, Any]]:
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
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            rows = data.get("listoumd", {}).get("rows", []) if isinstance(data, dict) else data
            if isinstance(rows, list) and rows:
                _uk_data = rows
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
    for prefix in ["улица ", "ул. ", "ул ", "проспект ", "пр. ", "пр-т ",
                    "бульвар ", "б-р ", "проезд ", "переулок ", "пер. "]:
        if s.startswith(prefix):
            s = s[len(prefix):]
    # Убираем лишние пробелы
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def _normalize_building(building: str) -> str:
    """Нормализует номер дома"""
    b = building.lower().strip()
    b = re.sub(r'\s+', '', b)
    # "корп." → "/"
    b = re.sub(r'корп\.?\s*', '/', b)
    return b


def _extract_street_and_building(address: str) -> Tuple[Optional[str], Optional[str]]:
    """Извлекает улицу и номер дома из адреса"""
    addr = address.strip()

    # Специальный паттерн для "60 лет Октября" и подобных числовых улиц
    m = re.search(r'(?:ул(?:ица)?\.?\s+)?(\d+\s+лет\s+[А-Яа-яёЁ]+)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я/]*)', addr, re.IGNORECASE)
    if m:
        return m.group(1).strip(), m.group(2).strip()

    # Паттерн: "ул. Мира, д. 10" или "улица Мира 10" или "Мира, 10"
    patterns = [
        r'(?:ул(?:ица)?\.?\s+|пр(?:оспект)?\.?\s+|б(?:ульвар)?\.?\s+|пер(?:еулок)?\.?\s+|проезд\s+)?'
        r'([А-Яа-яёЁ][А-Яа-яёЁ\s\-]+?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+\s*[а-яА-Я/]*(?:\s*корп\.?\s*\d+)?)',
    ]

    for pat in patterns:
        m = re.search(pat, addr)
        if m:
            street = m.group(1).strip().rstrip(',').strip()
            building = m.group(2).strip()
            if len(street) >= 2:
                return street, building

    return None, None


def find_uk_by_address(address: str) -> Optional[Dict[str, Any]]:
    """Находит УК по текстовому адресу (улица + дом)"""
    uk_list = _load_uk_data()
    if not uk_list:
        return None

    street, building = _extract_street_and_building(address)
    if not street:
        return None

    norm_street = _normalize_street(street)
    norm_building = _normalize_building(building) if building else None

    for uk in uk_list:
        for mkd in uk.get("MKD", []):
            mkd_street = _normalize_street(mkd.get("STREET", ""))
            # Сравниваем улицы (подстрока в обе стороны)
            if not (norm_street in mkd_street or mkd_street in norm_street):
                continue
            # Если нет номера дома — возвращаем первую УК на этой улице
            if not norm_building:
                return _format_uk(uk, mkd.get("STREET"))
            # Ищем номер дома
            buildings = mkd.get("BUILDINGS", [])
            for b in buildings:
                if _normalize_building(b) == norm_building or norm_building == _normalize_building(b):
                    return _format_uk(uk, mkd.get("STREET"), b)
            # Пробуем без буквы (10а → 10)
            base_num = re.match(r'(\d+)', norm_building)
            if base_num:
                for b in buildings:
                    b_num = re.match(r'(\d+)', _normalize_building(b))
                    if b_num and b_num.group(1) == base_num.group(1):
                        return _format_uk(uk, mkd.get("STREET"), b)

    return None


async def find_uk_by_coords(lat: float, lon: float) -> Optional[Dict[str, Any]]:
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


def _format_uk(uk: Dict[str, Any], street: str = None, building: str = None) -> Dict[str, Any]:
    """Форматирует данные УК для вывода"""
    return {
        "name": uk.get("TITLESM") or uk.get("TITLE", ""),
        "full_name": uk.get("TITLE", ""),
        "phone": uk.get("TEL"),
        "email": uk.get("EMAIL"),
        "address": uk.get("ADR"),
        "url": uk.get("URL"),
        "director": uk.get("FIO"),
        "work_time": uk.get("WORK_TIME"),
        "houses_count": uk.get("CNT", 0),
        "matched_street": street,
        "matched_building": building,
    }


def get_all_uk_emails() -> List[Dict[str, str]]:
    """Возвращает каталог всех УК, не только записей с email."""
    uk_list = _load_uk_data()
    result = []
    for uk in uk_list:
        name = (uk.get("TITLESM") or uk.get("TITLE", "")).strip()
        if not name:
            continue
        result.append({
            "name": name,
            "email": uk.get("EMAIL", ""),
            "phone": uk.get("TEL", ""),
            "houses": uk.get("CNT", 0),
        })
    return result
