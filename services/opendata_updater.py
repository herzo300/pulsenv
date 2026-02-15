# services/opendata_updater.py
"""
Автоматическое обновление opendata_full.json раз в сутки.
Запускается как фоновая задача при старте бота или отдельно.
"""

import os
import json
import asyncio
import logging
from datetime import datetime, timezone
import httpx
from core.http_client import get_http_client
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

API_KEY = os.getenv("NV_OPENDATA_API_KEY", "")
BASE_URL = "https://data.n-vartovsk.ru/api/v1"
DATA_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "opendata_full.json")
UPDATE_INTERVAL = 86400  # 24 часа в секундах

# Все датасеты для загрузки
DATASETS = {
    "listoumd": "8603032896-listoumd",
    "agstruct": "8603032896-agstruct",
    "agphonedir": "8603032896-agphonedir",
    "uchgkhservices": "8603032896-uchgkhservices",
    "tarif": "8603032896-tarif",
    "wastecollection": "8603032896-wastecollection",
    "buildlist": "8603032896-buildlist",
    "uchdou": "8603032896-uchdou",
    "uchou": "8603032896-uchou",
    "uchsport": "8603032896-uchsport",
    "uchculture": "8603032896-uchculture",
    "uchsportsection": "8603032896-uchsportsection",
    "topnameboys": "8603032896-topnameboys",
    "topnamegirls": "8603032896-topnamegirls",
    "averagesalary": "8603032896-averagesalary",
    "roadgasstationprice": "8603032896-roadgasstationprice",
    "mspsupport": "8603032896-mspsupport",
    "placespk": "8603032896-placespk",
    "placessg": "8603032896-placessg",
    "territoryplans": "8603032896-territoryplans",
    # Транспорт и дороги
    "busroute": "8603032896-busroute",
    "busstation": "8603032896-busstation",
    "roadgasstation": "8603032896-roadgasstation",
    "roadservice": "8603032896-roadservice",
    "roadworks": "8603032896-roadworks",
    # Образование и культура
    "uchcultureclubs": "8603032896-uchcultureclubs",
    "uchsporttrainers": "8603032896-uchsporttrainers",
    "uchoudod": "8603032896-uchoudod",
    # Строительство и земля
    "buildpermission": "8603032896-buildpermission",
    "buildreestr": "8603032896-buildreestr",
    "landplotsreestr": "8603032896-landplotsreestr",
    # Доступная среда и демография
    "dostupnayasreda": "8603032896-dostupnayasreda",
    "demography": "8603032896-demography",
    "publichearing": "8603032896-publichearing",
    "stvpgmu": "8603032896-stvpgmu",
    # === БЮДЖЕТ ===
    "budgetbulletin": "8603032896-budgetbulletin",
    "budgetinfo": "8603032896-budgetinfo",
    "budgetreport": "8603032896-budgetreport",
    # === МУНИЦИПАЛЬНЫЕ КОНТРАКТЫ (agreements) ===
    "agreementsdai": "8603032896-agreementsdai",       # Договоры аренды имущества
    "agreementsdkr": "8603032896-agreementsdkr",       # Договоры капремонта
    "agreementsek": "8603032896-agreementsek",         # Договоры энергосервис
    "agreementsgchp": "8603032896-agreementsgchp",     # Договоры ГЧП
    "agreementsiip": "8603032896-agreementsiip",       # Договоры инвестпроекты
    "agreementsik": "8603032896-agreementsik",         # Договоры инвестконтракты
    "agreementskjc": "8603032896-agreementskjc",       # Договоры КЖЦ
    "agreementsrip": "8603032896-agreementsrip",       # Договоры РИП
    "agreementssp": "8603032896-agreementssp",         # Договоры соцпартнёрство
    "agreementszpk": "8603032896-agreementszpk",       # Договоры ЗПК
    # === ИМУЩЕСТВО ===
    "propertyregisterlands": "8603032896-propertyregisterlands",
    "propertyregistermovableproperty": "8603032896-propertyregistermovableproperty",
    "propertyregisterrealestate": "8603032896-propertyregisterrealestate",
    "propertyregisterstoks": "8603032896-propertyregisterstoks",
    "infoprivatization": "8603032896-infoprivatization",
    "inforent": "8603032896-inforent",
    # === БИЗНЕС ===
    "businessevents": "8603032896-businessevents",
    "businessinfo": "8603032896-businessinfo",
    "msgsmp": "8603032896-msgsmp",
    # === РЕКЛАМА И СВЯЗЬ ===
    "advertisingconstructions": "8603032896-advertisingconstructions",
    "listcommunicationequipment": "8603032896-listcommunicationequipment",
    # === АРХИВ И ДОКУМЕНТЫ ===
    "archiveexpertise": "8603032896-archiveexpertise",
    "archivelistag": "8603032896-archivelistag",
    "docag": "8603032896-docag",
    "docaglink": "8603032896-docaglink",
    "docagtext": "8603032896-docagtext",
    "prglistag": "8603032896-prglistag",
    # === НОВОСТИ И ФОТО ===
    "sitelenta": "8603032896-sitelenta",
    "sitenews": "8603032896-sitenews",
    "siterubrics": "8603032896-siterubrics",
    "photoreports": "8603032896-photoreports",
    # === ПРОЧЕЕ ===
    "ogobsor": "8603032896-ogobsor",
    "otguid": "8603032896-otguid",
    "placesad": "8603032896-placesad",
}


async def _fetch_all_pages(client: httpx.AsyncClient, ds_id: str) -> list:
    """Загружает все страницы датасета."""
    all_rows = []
    page = 1
    while True:
        url = f"{BASE_URL}/{ds_id}/data?api_key={API_KEY}&ROWS=500&PAGE={page}"
        try:
            r = await client.get(url, headers={"User-Agent": "PulsGoroda/1.0"})
            if r.status_code != 200:
                break
            data = r.json()
            result = data.get("RESULT", {})
            rows = result.get("ROWS", [])
            if not rows:
                break
            all_rows.extend(rows)
            total_pages = result.get("META", {}).get("PAGE_TOTAL", 1)
            if page >= total_pages:
                break
            page += 1
        except Exception as e:
            logger.error(f"Fetch page {page} of {ds_id}: {e}")
            break
    return all_rows


async def update_opendata() -> dict:
    """Обновляет opendata_full.json со всеми датасетами."""
    if not API_KEY:
        logger.warning("⚠️ NV_OPENDATA_API_KEY не задан, пропуск обновления")
        return {"error": "no api key"}

    logger.info("🔄 Начинаю обновление открытых данных...")
    result = {}
    now = datetime.now(timezone.utc).isoformat()

    async with get_http_client(timeout=30.0) as client:
        for key, ds_id in DATASETS.items():
            try:
                rows = await _fetch_all_pages(client, ds_id)
                result[key] = {"rows": rows, "meta": {"updated": now, "count": len(rows)}}
                logger.info(f"  ✅ {key}: {len(rows)} записей")
            except Exception as e:
                logger.error(f"  ❌ {key}: {e}")
                # Сохраняем старые данные если есть
                if os.path.exists(DATA_FILE):
                    try:
                        with open(DATA_FILE, "r", encoding="utf-8") as f:
                            old = json.load(f)
                        if key in old:
                            result[key] = old[key]
                            logger.info(f"  ♻️ {key}: используем кэш")
                    except Exception:
                        pass

    # Добавляем метаданные
    result["_meta"] = {"updated_at": now, "datasets_count": len(DATASETS)}

    # Сохраняем
    try:
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False)
        logger.info(f"✅ opendata_full.json обновлён ({len(result)-1} датасетов)")
    except Exception as e:
        logger.error(f"❌ Ошибка записи: {e}")

    return result


def get_last_update() -> str | None:
    """Возвращает дату последнего обновления."""
    try:
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            return data.get("_meta", {}).get("updated_at")
    except Exception:
        pass
    return None


def needs_update() -> bool:
    """Проверяет, нужно ли обновление (прошло > 24ч)."""
    last = get_last_update()
    if not last:
        return True
    try:
        last_dt = datetime.fromisoformat(last)
        diff = datetime.now(timezone.utc) - last_dt
        return diff.total_seconds() > UPDATE_INTERVAL
    except Exception:
        return True


async def auto_update_loop():
    """Фоновой цикл обновления раз в сутки."""
    logger.info("🔄 Автообновление opendata запущено (интервал: 24ч)")
    while True:
        try:
            if needs_update():
                await update_opendata()
            else:
                last = get_last_update()
                logger.info(f"📦 Данные актуальны (обновлены: {last})")
        except Exception as e:
            logger.error(f"Auto-update error: {e}")
        await asyncio.sleep(UPDATE_INTERVAL)
