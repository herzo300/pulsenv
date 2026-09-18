# services/Backend/routers/fuel_stations.py
import logging
import random
import os
import time
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Request
from pydantic import BaseModel
import httpx
from bs4 import BeautifulSoup

router = APIRouter(prefix="/api/fuel", tags=["fuel"])
logger = logging.getLogger(__name__)

# Кэш цен по регионам: { region_slug: { "prices": { ... }, "last_update": 12345 } }
_cached_regional_prices = {}

# Динамический интервал сканирования (180–900 с, 3–15 мин)
_scan_interval: int = random.randint(180, 900)
_next_scan_at: Optional[datetime] = None

# Точные координаты и адреса реальных АЗС в Нижневартовске
STATIONS_NIZHNEVARTOVSK = [
    {
        "id": "gpn_82",
        "name": "Газпромнефть №82",
        "brand": "Газпромнефть",
        "address": "ул. 2П-2, д. 8",
        "lat": 60.916723,
        "lng": 76.623190,
        "prices": {"ai92": 51.20, "ai95": 55.45, "dt": 68.30}
    },
    {
        "id": "rosneft_lenina",
        "name": "Роснефть",
        "brand": "Роснефть",
        "address": "ул. Ленина, д. 3Б",
        "lat": 60.941910,
        "lng": 76.570776,
        "prices": {"ai92": 50.85, "ai95": 54.95, "dt": 67.90}
    },
    {
        "id": "lukoil_60let",
        "name": "Лукойл",
        "brand": "Лукойл",
        "address": "ул. 60 лет Октября, д. 1",
        "lat": 60.932943,
        "lng": 76.586118,
        "prices": {"ai92": 52.10, "ai95": 56.70, "dt": 69.10}
    },
    {
        "id": "okis_aviatorov",
        "name": "ОКИС",
        "brand": "ОКИС",
        "address": "ул. Авиаторов, д. 5",
        "lat": 60.963493,
        "lng": 76.495001,
        "prices": {"ai92": 49.90, "ai95": 53.90, "dt": 66.50}
    },
    {
        "id": "gpn_84",
        "name": "Газпромнефть №84",
        "brand": "Газпромнефть",
        "address": "ул. Индустриальная, д. 29",
        "lat": 60.923838,
        "lng": 76.602283,
        "prices": {"ai92": 51.30, "ai95": 55.55, "dt": 68.40}
    },
    {
        "id": "rosneft_severnaya",
        "name": "Роснефть",
        "brand": "Роснефть",
        "address": "ул. Северная, д. 54",
        "lat": 60.957778,
        "lng": 76.571932,
        "prices": {"ai92": 50.90, "ai95": 55.05, "dt": 67.95}
    },
    {
        "id": "lukoil_hm_20",
        "name": "Лукойл",
        "brand": "Лукойл",
        "address": "ул. Ханты-Мансийская, д. 20",
        "lat": 60.928770,
        "lng": 76.607500,
        "prices": {"ai92": 52.10, "ai95": 56.70, "dt": 69.10}
    },
    {
        "id": "okis_2p2_2",
        "name": "ОКИС-С",
        "brand": "ОКИС",
        "address": "ул. 2П-2, д. 2",
        "lat": 60.929842,
        "lng": 76.536848,
        "prices": {"ai92": 49.90, "ai95": 53.90, "dt": 66.50}
    },
    {
        "id": "gpn_internat_89a",
        "name": "Газпромнефть №93",
        "brand": "Газпромнефть",
        "address": "ул. Интернациональная, д. 89А",
        "lat": 60.953500,
        "lng": 76.620100,
        "prices": {"ai92": 51.30, "ai95": 55.55, "dt": 68.40}
    },
    {
        "id": "gpn_internat_62",
        "name": "Газпромнефть №94",
        "brand": "Газпромнефть",
        "address": "ул. Интернациональная, д. 62",
        "lat": 60.949000,
        "lng": 76.595000,
        "prices": {"ai92": 51.30, "ai95": 55.55, "dt": 68.40}
    },
    {
        "id": "gpn_indust_52",
        "name": "Газпромнефть №95",
        "brand": "Газпромнефть",
        "address": "ул. Индустриальная, д. 52",
        "lat": 60.920100,
        "lng": 76.592000,
        "prices": {"ai92": 51.30, "ai95": 55.55, "dt": 68.40}
    },
    {
        "id": "rosneft_indust_2",
        "name": "Роснефть",
        "brand": "Роснефть",
        "address": "ул. Индустриальная, д. 2",
        "lat": 60.922500,
        "lng": 76.582000,
        "prices": {"ai92": 50.90, "ai95": 55.05, "dt": 67.95}
    },
    {
        "id": "rosneft_aviatorov_8",
        "name": "Роснефть",
        "brand": "Роснефть",
        "address": "ул. Авиаторов, д. 8",
        "lat": 60.962000,
        "lng": 76.505000,
        "prices": {"ai92": 50.90, "ai95": 55.05, "dt": 67.95}
    },
    {
        "id": "rosneft_raduzh_2b",
        "name": "Роснефть",
        "brand": "Роснефть",
        "address": "Автодорога НВ-Радужный, д. 2Б",
        "lat": 60.985000,
        "lng": 76.635000,
        "prices": {"ai92": 50.90, "ai95": 55.05, "dt": 67.95}
    },
    {
        "id": "rosneft_raduzh_22km",
        "name": "Роснефть (Пригород)",
        "brand": "Роснефть",
        "address": "22-й км автодороги Нижневартовск-Радужный",
        "lat": 61.121000,
        "lng": 76.755000,
        "prices": {"ai92": 50.90, "ai95": 55.05, "dt": 67.95}
    },
    {
        "id": "lukoil_indust_119",
        "name": "Лукойл",
        "brand": "Лукойл",
        "address": "ул. Индустриальная, д. 119",
        "lat": 60.910500,
        "lng": 76.625000,
        "prices": {"ai92": 52.10, "ai95": 56.70, "dt": 69.10}
    },
    {
        "id": "lukoil_zhukova_27p",
        "name": "Лукойл",
        "brand": "Лукойл",
        "address": "ул. Маршала Жукова, д. 27П",
        "lat": 60.939200,
        "lng": 76.618000,
        "prices": {"ai92": 52.10, "ai95": 56.70, "dt": 69.10}
    },
    {
        "id": "okis_severnaya_37a",
        "name": "ОКИС-С",
        "brand": "ОКИС",
        "address": "ул. Северная, д. 37А",
        "lat": 60.959200,
        "lng": 76.592000,
        "prices": {"ai92": 49.90, "ai95": 53.90, "dt": 66.50}
    },
    {
        "id": "gpn_surgut_196km",
        "name": "Газпромнефть (Пригород)",
        "brand": "Газпромнефть",
        "address": "Автодорога Сургут-Нижневартовск, 196 км",
        "lat": 60.965000,
        "lng": 76.320000,
        "prices": {"ai92": 51.30, "ai95": 55.55, "dt": 68.40}
    }
]

# Реальные АЗС в Новосибирске
STATIONS_NOVOSIBIRSK = [
    {
        "id": "gpn_nsk_1",
        "name": "Газпромнефть №101",
        "brand": "Газпромнефть",
        "address": "Красный проспект, д. 100",
        "lat": 55.055100,
        "lng": 82.915200,
        "prices": {"ai92": 49.50, "ai95": 53.20, "dt": 65.80}
    },
    {
        "id": "rosneft_nsk_1",
        "name": "Роснефть",
        "brand": "Роснефть",
        "address": "ул. Дуси Ковальчук, д. 260",
        "lat": 55.059200,
        "lng": 82.908100,
        "prices": {"ai92": 49.20, "ai95": 52.80, "dt": 65.50}
    },
    {
        "id": "lukoil_nsk_1",
        "name": "Лукойл",
        "brand": "Лукойл",
        "address": "ул. Ипподромская, д. 45",
        "lat": 55.042300,
        "lng": 82.942100,
        "prices": {"ai92": 50.80, "ai95": 54.90, "dt": 66.90}
    },
    {
        "id": "gpn_nsk_2",
        "name": "Газпромнефть №105",
        "brand": "Газпромнефть",
        "address": "ул. Большевистская, д. 125",
        "lat": 55.008200,
        "lng": 82.956700,
        "prices": {"ai92": 49.60, "ai95": 53.30, "dt": 65.90}
    },
    {
        "id": "prime_nsk",
        "name": "Прайм",
        "brand": "Прайм",
        "address": "ул. Военная, д. 8",
        "lat": 55.029800,
        "lng": 82.943200,
        "prices": {"ai92": 48.90, "ai95": 51.90, "dt": 64.95}
    }
]

async def _fetch_current_regional_prices(region_slug: str) -> Dict[str, float]:
    """Парсит средние цены на топливо в указанном регионе с russiabase.ru."""
    url = f"https://russiabase.ru/prices/{region_slug}"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    # Базовые цены по умолчанию (в зависимости от региона)
    if "novosibirsk" in region_slug:
        prices = {"ai92": 49.50, "ai95": 53.20, "dt": 65.80}
    else:
        prices = {"ai92": 51.50, "ai95": 55.80, "dt": 68.20}
    
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, 'html.parser')
                table = soup.find('table')
                if table:
                    rows = table.find_all('tr')
                    for row in rows:
                        cols = [c.text.strip().lower() for c in row.find_all(['td', 'th'])]
                        if len(cols) >= 2:
                            fuel_name = cols[0]
                            try:
                                price_val = float(cols[1].replace("руб", "").replace("₽", "").strip().replace(",", "."))
                                if "92" in fuel_name:
                                    prices["ai92"] = price_val
                                elif "95" in fuel_name:
                                    prices["ai95"] = price_val
                                elif "дизел" in fuel_name or "дт" in fuel_name:
                                    prices["dt"] = price_val
                            except Exception:
                                pass
                logger.info("Parsed fuel prices for %s from russiabase: %s", region_slug, prices)
    except Exception as e:
        logger.warning("Failed to parse fuel prices for %s: %s. Using default values.", region_slug, e)
        
    return prices

@router.get("/stations")
async def get_fuel_stations(city: str = "nizhnevartovsk") -> List[Dict[str, Any]]:
    """Возвращает список АЗС с координатами и ценами на бензин для указанного города."""
    global _cached_regional_prices, _scan_interval, _next_scan_at
    
    # Определяем регион для парсинга и шаблон АЗС
    if city == "novosibirsk":
        region_slug = "novosibirskaya-oblast"
        template = STATIONS_NOVOSIBIRSK
    else:
        region_slug = "hmao-yugra"
        template = STATIONS_NIZHNEVARTOVSK
        
    now = time.time()
    
    # Проверяем кэш для конкретного региона (динамический TTL 180–900 с)
    cached = _cached_regional_prices.get(region_slug)
    should_rescan = not cached or (now - cached["last_update"] > _scan_interval)

    if should_rescan:
        prices = await _fetch_current_regional_prices(region_slug)
        # Ре-рандомизируем интервал после каждого сканирования
        _scan_interval = random.randint(180, 900)
        _next_scan_at = datetime.utcnow() + timedelta(seconds=_scan_interval)
        _cached_regional_prices[region_slug] = {
            "prices": prices,
            "last_update": now
        }
    else:
        prices = cached["prices"]
        
    base_92 = prices.get("ai92", 51.50)
    base_95 = prices.get("ai95", 55.80)
    base_dt = prices.get("dt", 68.20)
    
    stations = []
    for s in template:
        station_prices = {}
        brand_lower = s["brand"].lower()
        
        # Индивидуальный оффсет цен по брендам
        if "лукойл" in brand_lower:
            offset_92 = 0.65
            offset_95 = 0.90
            offset_dt = 0.95
        elif "газпром" in brand_lower:
            offset_92 = 0.10
            offset_95 = 0.15
            offset_dt = 0.20
        elif "окис" in brand_lower or "прайм" in brand_lower:
            offset_92 = -1.20
            offset_95 = -1.40
            offset_dt = -1.50
        else:  # Роснефть
            offset_92 = -0.30
            offset_95 = -0.40
            offset_dt = -0.30
            
        station_prices["ai92"] = round(base_92 + offset_92, 2)
        station_prices["ai95"] = round(base_95 + offset_95, 2)
        station_prices["dt"] = round(base_dt + offset_dt, 2)
        
        station_data = s.copy()
        station_data["prices"] = station_prices
        stations.append(station_data)

    # Находим 3 самых дешёвых по ai95 и помечаем их
    sorted_by_price = sorted(stations, key=lambda s: s["prices"]["ai95"])
    cheapest_ids = {s["id"] for s in sorted_by_price[:3]}
    scanned_at = datetime.utcnow().isoformat()
    for s in stations:
        s["is_cheapest"] = s["id"] in cheapest_ids
        s["last_scanned_at"] = scanned_at

    return stations


@router.get("/scan-status")
async def get_scan_status() -> Dict[str, Any]:
    """Возвращает информацию о следующем автоматическом обновлении цен."""
    global _scan_interval, _next_scan_at
    return {
        "scan_interval_seconds": _scan_interval,
        "next_scan_at": _next_scan_at.isoformat() if _next_scan_at else None,
        "next_scan_in_seconds": max(
            0,
            int((_next_scan_at - datetime.utcnow()).total_seconds())
        ) if _next_scan_at else None,
    }
