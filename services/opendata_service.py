# services/opendata_service.py
"""Сервис для работы с открытыми данными data.n-vartovsk.ru"""

import os
import json
import logging
import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import httpx
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

API_KEY = os.getenv("NV_OPENDATA_API_KEY", "")
BASE_URL = "https://data.n-vartovsk.ru/api/v1"
CACHE_FILE = "opendata_cache.json"
CACHE_TTL_HOURS = 24

# Ключевые датасеты для ЖКХ-мониторинга
DATASETS = {
    "listoumd": {
        "id": "8603032896-listoumd",
        "name": "Управляющие компании",
        "icon": "🏢",
        "description": "Перечень УК, ТСЖ, ЖСК города",
    },
    "agstruct": {
        "id": "8603032896-agstruct",
        "name": "Структура администрации",
        "icon": "🏛️",
        "description": "Подразделения администрации города",
    },
    "agphonedir": {
        "id": "8603032896-agphonedir",
        "name": "Телефонный справочник",
        "icon": "📞",
        "description": "Контакты администрации города",
    },
    "uchgkhservices": {
        "id": "8603032896-uchgkhservices",
        "name": "Услуги ЖКХ",
        "icon": "🔧",
        "description": "Перечень услуг ЖКХ",
    },
    "tarif": {
        "id": "8603032896-tarif",
        "name": "Тарифы ЖКХ",
        "icon": "💰",
        "description": "Тарифы на коммунальные услуги",
    },
    "wastecollection": {
        "id": "8603032896-wastecollection",
        "name": "Вывоз мусора",
        "icon": "🗑️",
        "description": "Площадки сбора отходов",
    },
    "buildlist": {
        "id": "8603032896-buildlist",
        "name": "Строительство",
        "icon": "🏗️",
        "description": "Объекты строительства",
    },
    "uchdou": {
        "id": "8603032896-uchdou",
        "name": "Детские сады",
        "icon": "👶",
        "description": "Дошкольные учреждения",
    },
    "uchou": {
        "id": "8603032896-uchou",
        "name": "Школы",
        "icon": "🏫",
        "description": "Общеобразовательные учреждения",
    },
    "uchsport": {
        "id": "8603032896-uchsport",
        "name": "Спортивные объекты",
        "icon": "⚽",
        "description": "Спортивные учреждения",
    },
    "uchculture": {
        "id": "8603032896-uchculture",
        "name": "Учреждения культуры",
        "icon": "🎭",
        "description": "Культурные учреждения города",
    },
    "placesad": {
        "id": "8603032896-placesad",
        "name": "Рекламные конструкции",
        "icon": "📋",
        "description": "Места размещения рекламы",
    },
}


# Кэш данных в памяти
_cache: Dict[str, Any] = {}
_cache_time: Optional[datetime] = None


def _load_cache() -> Dict[str, Any]:
    """Загрузить кэш из файла"""
    global _cache, _cache_time
    try:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            _cache_time = datetime.fromisoformat(data.get("updated_at", "2000-01-01"))
            _cache = data.get("datasets", {})
            return _cache
    except Exception as e:
        logger.error(f"Cache load error: {e}")
    return {}


def _save_cache():
    """Сохранить кэш в файл"""
    try:
        data = {
            "updated_at": datetime.utcnow().isoformat(),
            "datasets": _cache,
        }
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.error(f"Cache save error: {e}")


def _is_cache_fresh() -> bool:
    """Проверить актуальность кэша"""
    if not _cache_time:
        return False
    return (datetime.utcnow() - _cache_time) < timedelta(hours=CACHE_TTL_HOURS)


async def fetch_dataset(dataset_id: str, rows: int = 100, page: int = 1) -> Dict[str, Any]:
    """Получить данные датасета через API"""
    if not API_KEY:
        return {"error": "NV_OPENDATA_API_KEY не задан в .env"}

    url = f"{BASE_URL}/{dataset_id}/data?api_key={API_KEY}&ROWS={rows}&PAGE={page}"
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.get(url, headers={"User-Agent": "PulsGoroda/1.0"})
            if r.status_code == 200:
                return r.json()
            return {"error": f"HTTP {r.status_code}", "body": r.text[:200]}
    except Exception as e:
        return {"error": str(e)}


async def fetch_passport(dataset_id: str) -> Dict[str, Any]:
    """Получить паспорт датасета"""
    if not API_KEY:
        return {"error": "NV_OPENDATA_API_KEY не задан"}

    url = f"{BASE_URL}/{dataset_id}/passport?api_key={API_KEY}"
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.get(url, headers={"User-Agent": "PulsGoroda/1.0"})
            if r.status_code == 200:
                return r.json()
            return {"error": f"HTTP {r.status_code}"}
    except Exception as e:
        return {"error": str(e)}


async def refresh_all_datasets() -> Dict[str, Any]:
    """Обновить все датасеты (вызывается раз в день)"""
    global _cache, _cache_time
    results = {}

    for key, ds_info in DATASETS.items():
        ds_id = ds_info["id"]
        try:
            # Получаем первую страницу для подсчёта
            data = await fetch_dataset(ds_id, rows=5, page=1)
            if "error" in data:
                results[key] = {"error": data["error"]}
                continue

            result = data.get("RESULT", {})
            meta = result.get("META", {})
            rows_sample = result.get("ROWS", [])

            summary = {
                "id": ds_id,
                "name": ds_info["name"],
                "icon": ds_info["icon"],
                "description": ds_info["description"],
                "total_rows": meta.get("ROWS_TOTAL", 0),
                "total_pages": meta.get("PAGE_TOTAL", 0),
                "sample": rows_sample[:2],  # 2 примера
                "updated_at": datetime.utcnow().isoformat(),
            }

            _cache[key] = summary
            results[key] = summary
            logger.info(f"✅ {ds_info['name']}: {meta.get('ROWS_TOTAL', 0)} записей")

        except Exception as e:
            results[key] = {"error": str(e)}
            logger.error(f"❌ {ds_info['name']}: {e}")

    _cache_time = datetime.utcnow()
    _save_cache()
    return results


async def get_all_summaries() -> Dict[str, Any]:
    """Получить суммарные данные по всем датасетам (из кэша или обновить)"""
    global _cache
    if not _cache:
        _load_cache()

    if not _cache or not _is_cache_fresh():
        await refresh_all_datasets()

    return {
        "success": True,
        "updated_at": _cache_time.isoformat() if _cache_time else None,
        "datasets": _cache,
        "count": len(_cache),
    }


async def get_dataset_detail(key: str, rows: int = 20, page: int = 1) -> Dict[str, Any]:
    """Получить детальные данные конкретного датасета"""
    ds_info = DATASETS.get(key)
    if not ds_info:
        return {"error": f"Датасет '{key}' не найден"}

    data = await fetch_dataset(ds_info["id"], rows=rows, page=page)
    if "error" in data:
        return data

    result = data.get("RESULT", {})
    return {
        "success": True,
        "name": ds_info["name"],
        "icon": ds_info["icon"],
        "meta": result.get("META", {}),
        "rows": result.get("ROWS", []),
    }


async def search_uk_by_address(address: str) -> List[Dict[str, Any]]:
    """Найти управляющую компанию по адресу"""
    data = await fetch_dataset("8603032896-listoumd", rows=100, page=1)
    if "error" in data:
        return []

    rows = data.get("RESULT", {}).get("ROWS", [])
    results = []
    addr_lower = address.lower()

    for uk in rows:
        mkd_list = uk.get("MKD", [])
        for mkd in mkd_list:
            street = (mkd.get("STREET") or "").lower()
            buildings = mkd.get("BUILDINGS", [])
            if addr_lower in street or street in addr_lower:
                results.append({
                    "uk_name": uk.get("TITLESM") or uk.get("TITLE"),
                    "uk_full": uk.get("TITLE"),
                    "phone": uk.get("TEL"),
                    "email": uk.get("EMAIL"),
                    "address": uk.get("ADR"),
                    "url": uk.get("URL"),
                    "fio": uk.get("FIO"),
                    "street": mkd.get("STREET"),
                    "buildings": buildings,
                    "cnt": uk.get("CNT"),
                })
                break

    return results
