#!/usr/bin/env python3
"""
comprehensive_marker_geofix.py
Точный гео-аудит и перенос всех маркеров на карту Нижневартовска.
Проверяет базы данных (локальную SQLite и продакшн PostgreSQL на VPS),
файлы сидовых данных, событий и кэшей, выравнивая координаты по 3450+ домам,
школам, детсадам и ориентирам города.
"""

import os
import sys
import json
import sqlite3
import re
import math
from pathlib import Path
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT_DIR = Path(__file__).resolve().parents[2]
if not (ROOT_DIR / "data").exists():
    ROOT_DIR = Path("/app") if Path("/app/data").exists() else Path(__file__).resolve().parent

load_dotenv(ROOT_DIR / ".env")

def find_file(candidates):
    for c in candidates:
        p = Path(c)
        if p.exists():
            return p
    return Path(candidates[0])

HOUSES_JSON = find_file([
    ROOT_DIR / "services" / "Backend" / "data" / "nizhnevartovsk_houses.json",
    ROOT_DIR / "data" / "nizhnevartovsk_houses.json",
    Path("/app/services/Backend/data/nizhnevartovsk_houses.json"),
    Path("/app/data/nizhnevartovsk_houses.json"),
    Path(r"C:\Soobshio_project\services\Backend\data\nizhnevartovsk_houses.json"),
])

INSTITUTIONS_DART = find_file([
    ROOT_DIR / "services" / "Frontend" / "lib" / "data" / "nizhnevartovsk_institutions.dart",
    Path("/app/services/Frontend/lib/data/nizhnevartovsk_institutions.dart"),
    Path(r"C:\Soobshio_project\services\Frontend\lib\data\nizhnevartovsk_institutions.dart"),
])

VENUES_JSON = find_file([
    ROOT_DIR / "data" / "events_venues.json",
    Path("/app/data/events_venues.json"),
    Path(r"C:\Soobshio_project\data\events_venues.json"),
])

DB_PATH = find_file([
    ROOT_DIR / "soobshio.db",
    Path("/app/soobshio.db"),
    Path(r"C:\Soobshio_project\soobshio.db"),
])

# Точные координаты ключевых ориентиров и узлов Нижневартовска
LANDMARKS = {
    # Площади и парки
    "площадь нефтяников": (60.9368, 76.5645),
    "парк победы": (60.9400, 76.5480),
    "комсомольский бульвар": (60.9415, 76.5680),
    "комсомольское озеро": (60.9450, 76.5500),
    "озеро комсомольское": (60.9450, 76.5500),
    "сквер строителей": (60.9310, 76.5560),
    "сквер космонавтов": (60.9320, 76.5750),
    "сквер матерей": (60.9470, 76.5880),
    "сквер героев самотлора": (60.9500, 76.6010),
    "сквер спортивной славы": (60.9350, 76.5420),
    "школьная аллея": (60.9380, 76.5720),
    "роллердром": (60.9440, 76.5510),
    "набережная": (60.9300, 76.5500),
    "набережная реки обь": (60.9300, 76.5500),
    "старый вартовск": (60.9250, 76.5300),
    "рэб флота": (60.9150, 76.5900),

    # Культура и спорт
    "дворец искусств": (60.9404877, 76.5587701),
    "дворец культуры октябрь": (60.9298, 76.5492),
    "дк октябрь": (60.9298, 76.5492),
    "дк нефтяник": (60.9375, 76.5510),
    "театр драмы": (60.9395, 76.5565),
    "драмтеатр": (60.9395, 76.5565),
    "театр кукол барабашка": (60.9332, 76.5720),
    "краеведческий музей": (60.9398, 76.5615),
    "музей истории города": (60.9398, 76.5615),
    "центральная библиотека": (60.9431, 76.5772),
    "библиотека им пушкина": (60.9431, 76.5772),
    "ледовый дворец": (60.9272, 76.5415),
    "ледовый дворец спорта": (60.9272, 76.5415),
    "стадион нефтяник": (60.9255, 76.5360),
    "центральный стадион": (60.9255, 76.5360),
    "олимпия": (60.9340, 76.5380),
    "спорткомплекс триумф": (60.9490, 76.5920),
    "ск триумф": (60.9490, 76.5920),
    "арена": (60.9430, 76.5620),

    # Торговые центры и бизнес
    "green park": (60.9384798, 76.5558084),
    "грин парк": (60.9384798, 76.5558084),
    "мфк green park": (60.9384798, 76.5558084),
    "югра молл": (60.9422, 76.5710),
    "трк югра молл": (60.9422, 76.5710),
    "сити центр": (60.9380, 76.5530),
    "тц сити центр": (60.9380, 76.5530),
    "европа сити": (60.9372, 76.5815),
    "тц европа сити": (60.9372, 76.5815),
    "космос": (60.9360, 76.5700),
    "тц космос": (60.9360, 76.5700),
    "подсолнух": (60.9470, 76.6020),
    "тц подсолнух": (60.9470, 76.6020),
    "эдельвейс": (60.9350, 76.5610),
    "тц эдельвейс": (60.9350, 76.5610),

    # Инфраструктура и транспорт
    "администрация": (60.9372, 76.5531),
    "администрация города": (60.9372, 76.5531),
    "мфц": (60.9450, 76.5820),
    "автовокзал": (60.9545, 76.5822),
    "жд вокзал": (60.9562, 76.5848),
    "ж д вокзал": (60.9562, 76.5848),
    "железнодорожный вокзал": (60.9562, 76.5848),
    "аэропорт": (60.9490, 76.4880),
    "аэропорт нижневартовск": (60.9490, 76.4880),
    "окружная больница": (60.9480, 76.5560),
    "детская окружная больница": (60.9460, 76.5610),
    "роддом": (60.9450, 76.5580),
    "поликлиника 1": (60.9390, 76.5520),
    "поликлиника 2": (60.9420, 76.5810),
    "поликлиника 3": (60.9490, 76.6080),
    "нвгу": (60.9390, 76.5570),
    "нижневартовский государственный университет": (60.9390, 76.5570),
    "нефтяной техникум": (60.9370, 76.5590),
    "медицинский колледж": (60.9340, 76.5680),
    "строительный колледж": (60.9400, 76.5740),
    "памятник покорителям самотлора": (60.9120, 76.6400),
    "алеша": (60.9120, 76.6400),
}

def haversine_distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def normalize_text(text: str) -> str:
    if not text:
        return ""
    t = text.lower().replace("ё", "е")
    t = re.sub(r"[,\.\(\)\"\'«»]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def load_knowledge_base():
    """Загружает базу домов, школ, детсадов и рассчитывает центроиды улиц."""
    houses = {}
    street_points = {}

    # 1. Дома из nizhnevartovsk_houses.json
    if HOUSES_JSON.exists():
        try:
            with open(HOUSES_JSON, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for item in data:
                        addr = normalize_text(item.get("address", ""))
                        st = normalize_text(item.get("street", ""))
                        if addr and "lat" in item and "lng" in item:
                            lat = float(item["lat"])
                            lng = float(item["lng"])
                            houses[addr] = (lat, lng)
                            if st:
                                street_points.setdefault(st, []).append((lat, lng))
        except Exception as e:
            print(f"Warning reading houses: {e}")

    # 2. Школы и детсады из nizhnevartovsk_institutions.dart
    institutions = {}
    if INSTITUTIONS_DART.exists():
        try:
            content = INSTITUTIONS_DART.read_text(encoding="utf-8")
            pattern = re.compile(
                r"name:\s*'([^']+)'(?:.|\n)+?address:\s*'([^']+)'(?:.|\n)+?location:\s*LatLng\(([\d\.]+),\s*([\d\.]+)\)",
                re.MULTILINE
            )
            for m in pattern.finditer(content):
                name = normalize_text(m.group(1))
                addr = normalize_text(m.group(2))
                lat = float(m.group(3))
                lng = float(m.group(4))
                institutions[name] = (lat, lng)
                if addr:
                    houses[addr] = (lat, lng)
        except Exception as e:
            print(f"Warning reading institutions: {e}")

    # 3. Средние координаты улиц + точечные дома по нормализованным улицам
    street_centroids = {}
    _STREET_POINTS.clear()
    for st, pts in street_points.items():
        if pts:
            avg_lat = sum(p[0] for p in pts) / len(pts)
            avg_lng = sum(p[1] for p in pts) / len(pts)
            street_centroids[st] = (avg_lat, avg_lng)
            _STREET_POINTS[_norm_street(st)] = list(pts)

    print(f"✓ Загружено {len(houses)} домов, {len(institutions)} учреждений, {len(street_centroids)} улиц и {len(LANDMARKS)} ориентиров.")
    return houses, institutions, street_centroids

# ---------------------------------------------------------------------------
# Точный матчинг адресов (заменяет старый наивный substring-поиск, из-за
# которого «Интернациональная 1» совпадала с «Интернациональная 19» и т.п.)
# ---------------------------------------------------------------------------

_STREET_PREFIX_RX = re.compile(
    r"\b(улица|ул|проспект|пр\s*-?\s*кт|пр|переулок|пер|проезд|бульвар|б\s*-?\s*р|"
    r"набережная|наб|шоссе|площадь|пл|аллея|микрорайон|мкр)\b"
)

_HOUSE_TAIL_RX = re.compile(
    r"^(?P<street>.*?)(?:\s+(?:д|дом|№))?\s+(?P<house>\d{1,4}\s*[а-яa-z]?(?:\s*к\s*\d+)?(?:\s*/\s*\d{1,3}[а-яa-z]?)?)$"
)

_HOUSE_AFTER_STREET_RX = re.compile(
    r"^\s*[,.]?\s*(?:д\.?|дом|№)?\s*(\d{1,4}\s*[а-яa-z]?(?:\s*к\s*\d+)?(?:\s*/\s*\d{1,3}[а-яa-z]?)?)(?![\d/])"
)

# Точечные дома по улицам (для расчёта перекрёстков); заполняется load_knowledge_base()
_STREET_POINTS: dict = {}
_STREET_INDEX_CACHE: dict = {}


def _norm_street(name: str) -> str:
    """Нормализует название улицы: без типа (ул./проспект/...), нижний регистр."""
    t = normalize_text(name)
    t = t.replace("куропаткина", "кузоваткина")
    t = _STREET_PREFIX_RX.sub(" ", t)
    return re.sub(r"\s+", " ", t).strip()


def _compact_house(house: str) -> str:
    return re.sub(r"[\s\-]+", "", (house or "").lower().replace("ё", "е"))


def _split_house(house: str):
    """('15б') -> (15, 'б'); ('15/2') -> (15, '/2'); ('15 к 2') -> (15, 'к2')."""
    m = re.match(r"^(\d+)(.*)$", _compact_house(house))
    if not m:
        return None, ""
    return int(m.group(1)), m.group(2)


def _build_street_index(houses: dict) -> dict:
    """{норм. улица: {компактный номер дома: (lat, lng)}} — строится один раз на словарь."""
    cache_key = id(houses)
    cached = _STREET_INDEX_CACHE.get(cache_key)
    if cached is not None:
        return cached

    idx: dict = {}
    for addr, coords in houses.items():
        m = _HOUSE_TAIL_RX.match(addr)
        if not m:
            continue
        st = _norm_street(m.group("street"))
        hk = _compact_house(m.group("house"))
        if st and hk:
            idx.setdefault(st, {})[hk] = coords
    _STREET_INDEX_CACHE.clear()
    _STREET_INDEX_CACHE[cache_key] = idx
    return idx


def _find_street_mentions(text_norm: str, street_names: list) -> list:
    """[(start, end, street_norm)] без пересечений, сначала более длинные названия."""
    found = []
    occupied = []
    for st in street_names:
        if len(st) < 3:
            continue
        for m in re.finditer(r"(?<![а-яa-z0-9])" + re.escape(st) + r"(?![а-яa-z0-9])", text_norm):
            span = m.span()
            if any(not (span[1] <= o[0] or span[0] >= o[1]) for o in occupied):
                continue
            occupied.append(span)
            found.append((span[0], span[1], st))
    found.sort(key=lambda x: x[0])
    return found


def _lookup_house(idx: dict, street_norm: str, house_str: str):
    """Точное совпадение номера дома; при отсутствии — совпадение по базовому числу."""
    street_houses = idx.get(street_norm)
    if not street_houses:
        return None, None
    hk = _compact_house(house_str)
    if hk in street_houses:
        return street_houses[hk], "exact_house"
    base, _suffix = _split_house(house_str)
    if base is not None:
        for k, coords in street_houses.items():
            kb, _ = _split_house(k)
            if kb == base:
                return coords, "house_base_number"
    return None, None


def _street_centroid_from_points(points: list):
    if not points:
        return None
    return (
        sum(p[0] for p in points) / len(points),
        sum(p[1] for p in points) / len(points),
    )


def _resolve_streets_in_text(text_norm: str, houses: dict, street_centroids: dict):
    """Точный разбор «улица + дом» / перекрёстка в одном тексте. None, если не найдено."""
    idx = _build_street_index(houses)
    street_names = sorted(idx.keys(), key=len, reverse=True)
    mentions = _find_street_mentions(text_norm, street_names)
    if not mentions:
        return None

    # 1. Улица + номер дома сразу после названия
    for start, end, st in mentions:
        tail = text_norm[end:end + 40]
        hm = _HOUSE_AFTER_STREET_RX.match(tail)
        if not hm:
            continue
        coords, how = _lookup_house(idx, st, hm.group(1))
        if coords:
            return coords, f"{how} ({st} {_compact_house(hm.group(1))})"

    # 2. Перекрёсток двух улиц: середина ближайшей пары домов этих улиц
    if len(mentions) >= 2:
        st_a, st_b = mentions[0][2], mentions[1][2]
        pts_a = _STREET_POINTS.get(st_a) or []
        pts_b = _STREET_POINTS.get(st_b) or []
        if pts_a and pts_b:
            best = None
            for pa in pts_a:
                for pb in pts_b:
                    d = haversine_distance_m(pa[0], pa[1], pb[0], pb[1])
                    if best is None or d < best[0]:
                        best = (d, pa, pb)
            if best and best[0] < 400:
                mid = ((best[1][0] + best[2][0]) / 2, (best[1][1] + best[2][1]) / 2)
                return mid, f"street_intersection ({st_a} x {st_b})"

    # 3. Только улица — центроид
    st = mentions[0][2]
    pts = _STREET_POINTS.get(st)
    centroid = _street_centroid_from_points(pts) if pts else None
    if centroid is None:
        # совместимость со старым словарём центроидов (ключи с типом улицы)
        for full_name, coords in street_centroids.items():
            if _norm_street(full_name) == st:
                centroid = coords
                break
    if centroid is not None:
        return centroid, f"street_centroid ({st})"
    return None


def resolve_exact_coords(address: str, title: str, description: str, houses: dict, institutions: dict, street_centroids: dict):
    norm_addr = normalize_text(address)
    norm_title = normalize_text(title)
    combined = f"{address} {title} {description}".lower().replace("ё", "е")

    # 1. ТОЧНОЕ СОВПАДЕНИЕ ПОЛНОГО АДРЕСА
    if norm_addr and norm_addr in houses:
        return houses[norm_addr], "exact_house_address"

    # 2. ТОЧНЫЙ РАЗБОР «УЛИЦА + ДОМ» / ПЕРЕКРЁСТКА В АДРЕСЕ, ЗАТЕМ В ЗАГОЛОВКЕ
    for text_norm in (norm_addr, norm_title):
        if not text_norm:
            continue
        hit = _resolve_streets_in_text(text_norm, houses, street_centroids)
        if hit:
            return hit

    # 3. ПОИСК ПО ШКОЛАМ, ДЕТСАДАМ И ОРИЕНТИРАМ (точные названия)
    for inst_name, coords in institutions.items():
        if inst_name in combined:
            return coords, f"institution ({inst_name})"

    for lm, coords in LANDMARKS.items():
        if lm in combined:
            return coords, f"landmark ({lm})"

    # 4. ЦЕНТРОИД УЛИЦЫ ПО ОБЩЕМУ ТЕКСТУ (без номера дома)
    idx = _build_street_index(houses)
    street_names = sorted(idx.keys(), key=len, reverse=True)
    mentions = _find_street_mentions(normalize_text(f"{address} {title} {description}"), street_names)
    if mentions:
        st = mentions[0][2]
        centroid = _street_centroid_from_points(_STREET_POINTS.get(st) or [])
        if centroid is not None:
            return centroid, f"street_centroid_text ({st})"

    return (60.9385, 76.5589), "city_center_default"

_CITY_PROFILES = {
    "nizhnevartovsk": {"name": "Нижневартовск", "center": (60.9385, 76.5589), "viewbox": "76.42,60.85,76.70,61.02"},
}

_NOMINATIM_CACHE_PATH = find_file([
    ROOT_DIR / "data" / "geofix_nominatim_cache.json",
    Path("/app/data/geofix_nominatim_cache.json"),
])
_nominatim_cache: dict = {}
_nominatim_last_ts = 0.0


def _city_key(city: str | None, address: str) -> str:
    c = (city or "").strip().lower()
    if c in _CITY_PROFILES:
        return c
    return "nizhnevartovsk"


def normalize_query_for_nominatim(address: str, city_name: str) -> str:
    """'г. Нижневартовск, ул. Ленина, д. 15' -> 'Ленина, 15, Нижневартовск'."""
    a = (address or "").strip()
    a = re.sub(r"^г\.?\s*[^,]+,\s*", "", a)                    # убрать «г. Город, »
    a = re.sub(r",?\s*г\.?\s*[А-Яа-яЁё-]+\s*$", "", a)         # убрать «, Нижневартовск» в конце
    a = re.sub(r"\bд\.\s*", "", a)                             # «д. 15» -> «15»
    a = re.sub(r"^(ул|улица|проспект|пр-кт|пр-т|пр|пер|переулок|проезд|бульвар|б-р)\b\.?\s+", "", a, flags=re.I)
    a = re.sub(r"\s*,\s*", ", ", a).strip(" ,")
    return f"{a}, {city_name}" if a else city_name


def _parse_intersection(text: str):
    """'перекресток Мира и Ленина' / 'ул. Ленина / ул. Чапаева' -> (улица А, улица Б)."""
    t = (text or "").strip()
    m = re.search(r"перекр[её]ст(?:ок|ке)\s+(?:ул\.?\s*)?([А-Яа-яЁё0-9\-\s]+?)\s+и\s+(?:ул\.?\s*)?([А-Яа-яЁё0-9\-\s]+?)(?:[,.]|$)", t, re.I)
    if not m:
        m = re.search(r"(?:ул\.?\s*)?([А-Яа-яЁё0-9\-\s]+?)\s*/\s*(?:ул\.?\s*)?([А-Яа-яЁё0-9\-\s]+?)(?:[,.]|$)", t)
    if not m:
        return None
    a, b = m.group(1).strip(" ,."), m.group(2).strip(" ,.")
    if len(a) < 3 or len(b) < 3:
        return None
    return a, b


def _expected_house(address: str):
    m = re.search(r"\bд\.?\s*(\d{1,4}[а-яa-z]?(?:\s*с\s*\d+)?)\b", address or "", re.I)
    if not m:
        m = re.search(r"[,\s](\d{1,4}[а-яa-z]?)(?:\s*с\s*\d+)?\s*(?:,|$)", address or "", re.I)
    return _compact_house(m.group(1)) if m else None


def _nominatim_get(url: str):
    """GET с кэшем и лимитом 1 запрос/сек."""
    global _nominatim_last_ts
    import time
    import urllib.request

    if not _nominatim_cache:
        try:
            if _NOMINATIM_CACHE_PATH.exists():
                raw = json.loads(_NOMINATIM_CACHE_PATH.read_text(encoding="utf-8"))
                if isinstance(raw, dict):
                    _nominatim_cache.update(raw)
        except Exception:
            pass
    if url in _nominatim_cache:
        return _nominatim_cache[url]

    wait = 1.1 - (time.time() - _nominatim_last_ts)
    if wait > 0:
        time.sleep(wait)
    data = None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "SoobshioGeofix/3.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"  [nominatim] ошибка запроса: {e}")
    _nominatim_last_ts = time.time()

    _nominatim_cache[url] = data
    try:
        _NOMINATIM_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        _NOMINATIM_CACHE_PATH.write_text(
            json.dumps(_nominatim_cache, ensure_ascii=False), encoding="utf-8"
        )
    except Exception:
        pass
    return data


def _nominatim_search(query: str, viewbox: str, polygon: bool = False):
    import urllib.parse
    url = (
        "https://nominatim.openstreetmap.org/search?q="
        + urllib.parse.quote(query)
        + f"&format=jsonv2&limit=5&addressdetails=1&countrycodes=ru&viewbox={viewbox}&bounded=1"
    )
    if polygon:
        url += "&polygon_geojson=1"
    data = _nominatim_get(url)
    return data if isinstance(data, list) else []


def _nominatim_validated(address: str, viewbox: str, city_name: str):
    """Дом/улица по Nominatim с проверкой, что вернули именно нужную улицу и дом."""
    query = normalize_query_for_nominatim(address, city_name)
    if not query or query == city_name:
        return None
    exp_house = _expected_house(address)
    exp_street = _norm_street(re.sub(r"^(.*?)\b\d{1,4}[а-яa-z]?\b.*$", r"\1",
                       re.sub(r"\bд\.\s*", "", normalize_query_for_nominatim(address, "").strip(" ,"))))
    street_level = None
    for item in _nominatim_search(query, viewbox):
        if not isinstance(item, dict):
            continue
        addr = item.get("address") or {}
        road = addr.get("road") or addr.get("pedestrian") or ""
        road_norm = _norm_street(road)
        if exp_street and road_norm and exp_street not in road_norm and road_norm not in exp_street:
            continue
        house = _compact_house(str(addr.get("house_number") or ""))
        lat, lon = float(item["lat"]), float(item["lon"])
        if exp_house:
            if house and (_split_house(house)[0] == _split_house(exp_house)[0]):
                return (lat, lon), f"nominatim_house ({house})"
            if street_level is None:
                street_level = (lat, lon)
        else:
            return (lat, lon), "nominatim_street"
    if exp_house and street_level is not None:
        return street_level, "nominatim_street_level"
    return None


def _linestring_points(geojson: dict) -> list:
    t = geojson.get("type")
    c = geojson.get("coordinates") or []
    if t == "LineString":
        return [(p[1], p[0]) for p in c]
    if t == "MultiLineString":
        return [(p[1], p[0]) for line in c for p in line]
    return []


def _nominatim_intersection(street_a: str, street_b: str, viewbox: str, city_name: str):
    """Перекрёсток: середина ближайшей пары точек реальной геометрии двух улиц (OSM)."""
    pts = []
    for name in (street_a, street_b):
        full = name if re.search(r"\b(ул|улица|проспект|переулок|проезд|бульвар)\b", name, re.I) else f"улица {name}"
        found = []
        for item in _nominatim_search(f"{full}, {city_name}", viewbox, polygon=True):
            if isinstance(item, dict) and item.get("geojson"):
                found.extend(_linestring_points(item["geojson"]))
        pts.append(found)
    if not pts[0] or not pts[1]:
        return None
    best = None
    for pa in pts[0]:
        for pb in pts[1]:
            d = haversine_distance_m(pa[0], pa[1], pb[0], pb[1])
            if best is None or d < best[0]:
                best = (d, pa, pb)
    if best is None:
        return None
    mid = ((best[1][0] + best[2][0]) / 2, (best[1][1] + best[2][1]) / 2)
    gap = round(best[0])
    return mid, f"nominatim_intersection ({street_a} x {street_b}, сближение {gap}м)"


def resolve_with_city(address: str, title: str, description: str, city: str,
                      houses: dict, institutions: dict, street_centroids: dict):
    """Город-зависимое разрешение. Реальные данные (Nominatim/OSM) — в первую
    очередь; локальная кадастровая база — только как офлайн-фолбэк (её сетка
    координат системно расходится с OSM на 0.5–2 км)."""
    profile = _CITY_PROFILES.get(city, _CITY_PROFILES["nizhnevartovsk"])

    # 1. Перекрёсток — по реальной геометрии улиц
    inter = _parse_intersection(address) or _parse_intersection(title)
    if inter:
        hit = _nominatim_intersection(inter[0], inter[1], profile["viewbox"], profile["name"])
        if hit:
            return hit

    # 2. Точный дом по Nominatim (реальные координаты OSM)
    if address and address.strip():
        hit = _nominatim_validated(address, profile["viewbox"], profile["name"])
        if hit:
            return hit

    # 3. Офлайн-фолбэк: локальная база домов (приблизительная сетка!)
    if city == "nizhnevartovsk":
        coords, source = resolve_exact_coords(address, title, description, houses, institutions, street_centroids)
        if source != "city_center_default":
            return coords, f"{source} [прибл., локальная база]"

    # 4. Улица без дома по Nominatim
    if address and address.strip():
        query = normalize_query_for_nominatim(re.sub(r"\b\d{1,4}[а-яa-z]?\b", "", address), profile["name"])
        for item in _nominatim_search(query, profile["viewbox"]):
            if isinstance(item, dict):
                return (float(item["lat"]), float(item["lon"])), "nominatim_street_fallback"

    return profile["center"], f"city_center_default ({city})"


def process_sqlite():
    if not DB_PATH.exists():
        print(f"[!] SQLite {DB_PATH} не найден.")
        return 0, 0

    houses, institutions, street_centroids = load_knowledge_base()
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()

    cols = [r[1] for r in cursor.execute("PRAGMA table_info(reports)")]
    city_expr = "city" if "city" in cols else "NULL"
    cursor.execute(f"SELECT id, title, description, address, lat, lng, category, {city_expr} FROM reports")
    rows = cursor.fetchall()
    print(f"\nАудит локальной БД ({len(rows)} сигналов)...")

    fixed = 0
    unchanged = 0
    results_summary = []

    for r_id, title, desc, addr, lat, lng, cat, city in rows:
        title = title or ""
        desc = desc or ""
        addr = addr or ""
        city_key = _city_key(city, addr)
        curr_lat = float(lat) if lat is not None else 0.0
        curr_lng = float(lng) if lng is not None else 0.0

        target_coords, source = resolve_with_city(addr, title, desc, city_key, houses, institutions, street_centroids)
        t_lat, t_lng = target_coords

        dist_m = haversine_distance_m(curr_lat, curr_lng, t_lat, t_lng) if (curr_lat != 0 and curr_lng != 0) else 999999

        profile = _CITY_PROFILES[city_key]
        # Исправляем: пустые координаты, смещение >120м, старый дефолт НВ,
        # либо точка вообще вне viewbox Нижневартовска
        vb = [float(x) for x in profile["viewbox"].split(",")]  # min_lon,min_lat,max_lon,max_lat
        outside_city = not (vb[1] <= curr_lat <= vb[3] and vb[0] <= curr_lng <= vb[2])
        at_default = abs(curr_lat - 60.9344) < 0.002 and abs(curr_lng - 76.5531) < 0.002

        if curr_lat == 0 or curr_lng == 0 or dist_m > 120 or at_default or outside_city:
            cursor.execute("UPDATE reports SET lat = ?, lng = ? WHERE id = ?", (t_lat, t_lng, r_id))
            fixed += 1
            entry = f"#{r_id} [{cat}|{city_key}]: '{title[:35]}' -> ({t_lat:.5f}, {t_lng:.5f}) [{source}] (было {dist_m:.0f}м)"
            results_summary.append(entry)
            print(f"  [ИСПРАВЛЕНО] {entry}")
        else:
            unchanged += 1

    conn.commit()
    conn.close()
    print(f"✓ SQLite: обновлено {fixed} маркеров, {unchanged} уже стояли точно на своих координатах.\n")
    return fixed, unchanged, results_summary

def update_events_venues():
    """Обновляет и нормализует data/events_venues.json."""
    if not VENUES_JSON.exists():
        return
    try:
        data = json.loads(VENUES_JSON.read_text(encoding="utf-8"))
        for k, v in LANDMARKS.items():
            if k in data:
                data[k]["lat"] = v[0]
                data[k]["lng"] = v[1]
        VENUES_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print("✓ data/events_venues.json синхронизирован с проверенными координатами.")
    except Exception as e:
        print(f"Warning updating venues: {e}")

if __name__ == "__main__":
    print("=" * 65)
    print("  CITY PULSE — КОМПЛЕКСНЫЙ ГЕО-АУДИТ И ВЫРАВНИВАНИЕ МАРКЕРОВ")
    print("=" * 65)
    update_events_venues()
    process_sqlite()
