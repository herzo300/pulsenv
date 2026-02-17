# services/geo_service.py
import asyncio
import re
from typing import Optional, Tuple

import httpx
from core.http_client import get_http_client

# Nominatim часто блокирует прокси или даёт таймауты — по умолчанию без прокси
GEO_USE_PROXY = False
GEO_MAX_RETRIES = 2
GEO_RETRY_DELAY = 0.5

_client: Optional[httpx.AsyncClient] = None


def get_client():
    """HTTP-клиент для геозапросов (Nominatim). По умолчанию без прокси для стабильности."""
    global _client
    if _client is None:
        kwargs = {
            "timeout": 15.0,
            "limits": httpx.Limits(max_connections=20, max_keepalive_connections=5),
        }
        if not GEO_USE_PROXY:
            kwargs["proxy"] = None
        _client = get_http_client(**kwargs)
    return _client

# Кэш для геокодинга (адрес -> координаты)
_geo_cache = {}

# Известные ориентиры Нижневартовска → координаты
NV_LANDMARKS = {
    "самотлор": (60.9398, 76.5652),
    "озеро комсомольское": (60.9450, 76.5500),
    "комсомольское озеро": (60.9450, 76.5500),
    "тц мегион": (60.9340, 76.5580),
    "тц сити центр": (60.9380, 76.5530),
    "сити центр": (60.9380, 76.5530),
    "тц югра молл": (60.9420, 76.5700),
    "югра молл": (60.9420, 76.5700),
    "тц западный": (60.9350, 76.5350),
    "западный": (60.9350, 76.5350),
    "тц мегаполис": (60.9370, 76.5600),
    "мегаполис": (60.9370, 76.5600),
    "автовокзал": (60.9410, 76.5730),
    "жд вокзал": (60.9560, 76.5850),
    "аэропорт": (60.9490, 76.4880),
    "городская больница": (60.9370, 76.5480),
    "поликлиника 1": (60.9360, 76.5520),
    "поликлиника 2": (60.9400, 76.5600),
    "школа 1": (60.9350, 76.5500),
    "школа 2": (60.9380, 76.5550),
    "администрация города": (60.9370, 76.5530),
    "площадь нефтяников": (60.9370, 76.5530),
    "парк победы": (60.9400, 76.5480),
    "дворец искусств": (60.9380, 76.5510),
    "ледовый дворец": (60.9420, 76.5650),
    "стадион центральный": (60.9390, 76.5560),
    "набережная": (60.9300, 76.5500),
    "район 10п": (60.9500, 76.5800),
    "район 10а": (60.9480, 76.5750),
    "район 2п": (60.9350, 76.5400),
    "район 6п": (60.9400, 76.5650),
    "район 7п": (60.9420, 76.5700),
    "район 17": (60.9300, 76.5350),
    "старый вартовск": (60.9250, 76.5300),
}


def extract_address_from_text(text: str) -> Optional[str]:
    """
    Расширенный парсер адресов из текста.
    Ищет улицы, проспекты, переулки, микрорайоны, перекрёстки.
    """
    # Сначала ищем перекрёстки (приоритет — более точная локация)
    intersection_patterns = [
        # перекрёсток ул. Мира и ул. Ленина / перекрёсток Мира и Ленина
        r'перекр[её]ст(?:ок|ке)\s+(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)\s+и\s+(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)',
        # угол Мира и Ленина / на углу Мира и Ленина
        r'(?:на\s+)?угл[уе]\s+(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)\s+и\s+(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)',
        # ул. Мира / ул. Ленина (через слэш)
        r'(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)\s*/\s*(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)',
        # пересечение Мира и Ленина
        r'пересечени[еи]\s+(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)\s+и\s+(?:ул(?:иц[еы]|\.)\s+)?([А-Яа-яЁё]+)',
    ]
    for pat in intersection_patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            street1, street2 = m.group(1).strip(), m.group(2).strip()
            skip = {'около', 'более', 'менее', 'через', 'после', 'перед'}
            if street1.lower() in skip or street2.lower() in skip:
                continue
            return f"перекрёсток ул. {street1} и ул. {street2}, Нижневартовск"

    # Затем ищем конкретные адреса (дом)
    patterns = [
        # ул. Мира 62, ул. Мира, 62, улица Мира 62
        r'(?:ул(?:ица|ице|\.)\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+[а-яА-Я]?(?:/\d+)?)',
        # пр. Победы 12, проспект Победы 12
        r'(?:пр(?:оспект|оспекте|\.)\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+[а-яА-Я]?(?:/\d+)?)',
        # пер. Лесной 5, переулок Лесной 5
        r'(?:пер(?:еулок|еулке|\.)\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+[а-яА-Я]?(?:/\d+)?)',
        # бульвар Мира 3
        r'(?:б(?:ульвар|ульваре|\.)\s+)([А-Яа-яЁё]+(?:\s+[А-Яа-яЁё]+)?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+[а-яА-Я]?(?:/\d+)?)',
        # мкр. 10П дом 5, микрорайон 10П дом 5
        r'(?:м(?:икрорайон|кр)\.?\s*)(\d+[а-яА-Я]?)\s*[,.]?\s*(?:д(?:ом)?\.?\s*)?(\d+[а-яА-Я]?(?:/\d+)?)',
        # дом 15 по ул. Мира
        r'(?:д(?:ом)?\.?\s*)(\d+[а-яА-Я]?)\s+(?:по\s+)?(?:ул(?:ице|\.)\s+)([А-Яа-яЁё]+)',
        # Мира 62 (без префикса, но с номером дома)
        r'(?:^|\s)([А-Яа-яЁё]{3,}(?:\s+[А-Яа-яЁё]+)?)\s+(\d{1,3}[а-яА-Я]?)\s*(?:[,.\s]|$)',
    ]

    for i, pat in enumerate(patterns):
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            if i == 4:  # мкр
                return f"мкр. {m.group(1)} д. {m.group(2)}, Нижневартовск"
            elif i == 5:  # дом по ул.
                return f"ул. {m.group(2)} {m.group(1)}, Нижневартовск"
            elif i == 6:  # без префикса
                street = m.group(1)
                # Фильтруем ложные срабатывания
                skip_words = {'около', 'более', 'менее', 'через', 'после', 'перед', 'возле', 'рядом', 'номер', 'этаж', 'подъезд'}
                if street.lower() in skip_words:
                    continue
                return f"ул. {street} {m.group(2)}, Нижневартовск"
            else:
                prefix = "ул." if i == 0 else "пр." if i == 1 else "пер." if i == 2 else "б-р"
                return f"{prefix} {m.group(1)} {m.group(2)}, Нижневартовск"

    return None


def find_landmark(text: str) -> Optional[Tuple[str, float, float]]:
    """Ищет известные ориентиры Нижневартовска в тексте."""
    t = text.lower()
    for name, (lat, lon) in NV_LANDMARKS.items():
        if name in t:
            return name, lat, lon
    return None

async def get_coordinates(address: str) -> Optional[Tuple[float, float]]:
    """
    Превращает адрес в координаты через Nominatim (OpenStreetMap).
    Возвращает (lat, lon) или None, если не найдено.
    Использует кэш для повторных запросов.
    """
    if not address:
        return None
    
    # Проверяем кэш
    cache_key = address.lower().strip()
    if cache_key in _geo_cache:
        return _geo_cache[cache_key]
    
    try:
        # Если адрес уже содержит "Нижневартовск" — не дублируем
        if 'нижневартовск' in address.lower():
            full_address = address
        else:
            full_address = f"Нижневартовск, {address}"

        headers = {"User-Agent": "SoobshioApp/1.0"}
        client = get_client()

        # Перекрёстки: "перекрёсток ул. X и ул. Y" → геокодим обе улицы, берём среднюю точку
        intersection_match = re.match(
            r'перекр[её]ст(?:ок|ке)\s+ул\.\s*(\S+)\s+и\s+ул\.\s*(\S+)',
            address, re.IGNORECASE
        )

        if intersection_match:
            street1 = intersection_match.group(1).rstrip(',')
            street2 = intersection_match.group(2).rstrip(',')
            queries = [
                f"улица {street1}, Нижневартовск",
                f"улица {street2}, Нижневартовск",
            ]
            coords_list = []
            for q in queries:
                try:
                    from urllib.parse import quote as _quote
                    q_url = f"https://nominatim.openstreetmap.org/search?q={_quote(q)}&format=json&limit=1"
                    resp = await client.get(q_url, headers=headers)
                    d = resp.json()
                    if d:
                        coords_list.append((float(d[0]["lat"]), float(d[0]["lon"])))
                except Exception:
                    pass
            if len(coords_list) == 2:
                lat = (coords_list[0][0] + coords_list[1][0]) / 2
                lon = (coords_list[0][1] + coords_list[1][1]) / 2
                _geo_cache[cache_key] = (lat, lon)
                return lat, lon
            elif len(coords_list) == 1:
                _geo_cache[cache_key] = coords_list[0]
                return coords_list[0]

        from urllib.parse import quote
        url = (
            "https://nominatim.openstreetmap.org/search"
            f"?q={quote(full_address)}&format=json&limit=1"
        )

        last_error = None
        for attempt in range(GEO_MAX_RETRIES + 1):
            try:
                resp = await client.get(url, headers=headers)
                resp.raise_for_status()
                data = resp.json()
                if not data:
                    return None
                lat = float(data[0]["lat"])
                lon = float(data[0]["lon"])
                _geo_cache[cache_key] = (lat, lon)
                return lat, lon
            except (httpx.TimeoutException, httpx.ConnectError) as e:
                last_error = e
                if attempt < GEO_MAX_RETRIES:
                    await asyncio.sleep(GEO_RETRY_DELAY * (attempt + 1))
                    continue
                break
            except Exception as e:
                last_error = e
                break

        if last_error:
            print(f"Geo error: {last_error}")
        return None
    except Exception as e:
        print(f"Geo error (outer): {e}")
        return None


def make_street_view_url(lat: float, lon: float) -> str:
    """
    Собирает ссылку Street View с маркером для заданных координат.
    Использует Google Maps URL с панорамой и точкой на карте.
    """
    return f"https://www.google.com/maps/@?api=1&map_action=pano&viewpoint={lat},{lon}&heading=0&pitch=0&fov=90"

def make_map_url(lat: float, lon: float, zoom: int = 15) -> str:
    """
    Собирает ссылку на карту OpenStreetMap.
    """
    return f"https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map={zoom}/{lat}/{lon}"

async def reverse_geocode(lat: float, lon: float) -> Optional[str]:
    """
    Обратное геокодирование: координаты -> адрес.
    """
    try:
        url = (
            "https://nominatim.openstreetmap.org/reverse"
            f"?lat={lat}&lon={lon}&format=json"
        )
        headers = {"User-Agent": "SoobshioApp/1.0"}
        
        client = get_client()
        resp = await client.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        
        return data.get("display_name")
        
    except Exception as e:
        print(f"Reverse geo error: {e}")
        return None


def close_geo_client():
    """Сбросить глобальный HTTP-клиент (следующий get_client() создаст новый)."""
    global _client
    _client = None

# Для обратной совместимости с синхронным кодом
def get_coordinates_sync(address: str) -> Optional[Tuple[float, float]]:
    """
    Синхронная версия get_coordinates (для legacy кода).
    """
    try:
        import requests
        full_address = f"Нижневартовск, {address}"
        url = (
            "https://nominatim.openstreetmap.org/search"
            f"?q={full_address}&format=json&limit=1"
        )
        headers = {"User-Agent": "SoobshioApp/1.0"}
        resp = requests.get(url, headers=headers, timeout=5)
        data = resp.json()
        
        if not data:
            return None
        
        lat = float(data[0]["lat"])
        lon = float(data[0]["lon"])
        return lat, lon
    except Exception as e:
        print(f"Geo sync error: {e}")
        return None


async def geoparse(text: str, ai_address: Optional[str] = None, location_hints: Optional[str] = None) -> dict:
    """
    Единый геопарсинг: извлекает адрес и координаты из текста.
    Приоритет: AI адрес → парсер адресов → ориентиры → location_hints.
    
    Возвращает: {"address": str|None, "lat": float|None, "lng": float|None, "geo_source": str}
    """
    result = {"address": None, "lat": None, "lng": None, "geo_source": None}

    # 1. AI адрес (самый точный)
    if ai_address:
        coords = await get_coordinates(ai_address)
        if coords:
            result["address"] = ai_address
            result["lat"], result["lng"] = coords
            result["geo_source"] = "ai_address"
            return result

    # 2. Парсер адресов из текста
    parsed_addr = extract_address_from_text(text)
    if parsed_addr:
        coords = await get_coordinates(parsed_addr)
        if coords:
            result["address"] = parsed_addr
            result["lat"], result["lng"] = coords
            result["geo_source"] = "text_parser"
            return result
        # Адрес найден, но не геокодирован — сохраняем без координат
        result["address"] = parsed_addr

    # 3. Ориентиры
    landmark = find_landmark(text)
    if landmark:
        name, lat, lon = landmark
        if not result["lat"]:
            result["lat"] = lat
            result["lng"] = lon
            result["geo_source"] = f"landmark:{name}"
        if not result["address"]:
            result["address"] = f"район {name}, Нижневартовск"

    # 4. location_hints от AI
    if location_hints and not result["lat"]:
        hint_landmark = find_landmark(location_hints)
        if hint_landmark:
            name, lat, lon = hint_landmark
            result["lat"] = lat
            result["lng"] = lon
            result["geo_source"] = f"hint:{name}"
            if not result["address"]:
                result["address"] = f"район {name}, Нижневартовск"
        else:
            # Попробуем геокодировать hint как адрес
            coords = await get_coordinates(f"{location_hints}, Нижневартовск")
            if coords:
                result["lat"], result["lng"] = coords
                result["geo_source"] = "hint_geocoded"
                if not result["address"]:
                    result["address"] = location_hints

    return result
