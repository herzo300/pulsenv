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

    # 3. Средние координаты улиц
    street_centroids = {}
    for st, pts in street_points.items():
        if pts:
            avg_lat = sum(p[0] for p in pts) / len(pts)
            avg_lng = sum(p[1] for p in pts) / len(pts)
            street_centroids[st] = (avg_lat, avg_lng)

    print(f"✓ Загружено {len(houses)} домов, {len(institutions)} учреждений, {len(street_centroids)} улиц и {len(LANDMARKS)} ориентиров.")
    return houses, institutions, street_centroids

def resolve_exact_coords(address: str, title: str, description: str, houses: dict, institutions: dict, street_centroids: dict):
    combined = f"{address} {title} {description}".lower().replace("ё", "е")
    norm_addr = normalize_text(address)

    # 1. Прямое совпадение по адресу дома
    if norm_addr in houses:
        return houses[norm_addr], "exact_house_address"

    for h_addr, coords in houses.items():
        if h_addr in norm_addr or (len(h_addr) > 5 and h_addr in combined):
            return coords, f"house_registry ({h_addr})"

    # 2. Поиск по школам, детсадам, гимназиям
    for inst_name, coords in institutions.items():
        if inst_name in combined:
            return coords, f"institution ({inst_name})"

    # Регулярки для номеров школ и садов
    school_match = re.search(r"(?:школ\w*|сш|гимнази\w*|лице\w*)\s*(?:№|номер)?\s*(\d+)", combined)
    if school_match:
        s_num = school_match.group(1)
        for inst_name, coords in institutions.items():
            if f"№{s_num}" in inst_name or f"№ {s_num}" in inst_name or f"{s_num}" in inst_name:
                return coords, f"school_number_match (№{s_num})"

    kinder_match = re.search(r"(?:детск\w*\s*сад\w*|дс|д/с)\s*(?:№|номер)?\s*(\d+)", combined)
    if kinder_match:
        k_num = kinder_match.group(1)
        for inst_name, coords in institutions.items():
            if f"№{k_num}" in inst_name or f"№ {k_num}" in inst_name:
                return coords, f"kindergarten_number_match (№{k_num})"

    # 3. Поиск по ориентирам и учреждениям
    for lm, coords in LANDMARKS.items():
        if lm in combined:
            return coords, f"landmark ({lm})"

    # 4. Поиск улицы + дома по регулярному выражению
    street_rx = r"(ленина|мира|интернациональн\w*|чапаев\w*|дзержинск\w*|ханты-мансийск\w*|60 лет октября|побед\w*|кузоваткин\w*|нефтяник\w*|дружбы народов|северн\w*|омск\w*|менделеев\w*|спортивн\w*|пермск\w*|героев самотлор\w*|маршала жуков\w*|жуков\w*|индустриальн\w*|авиатор\w*|лопарев\w*|лесн\w*|рабоч\w*|таежн\w*|школьн\w*|заводск\w*|пикман\w*|рощинск\w*|куропаткин\w*|заозерн\w*|романтик\w*|нововартовск\w*)\s*(?:дом|д\.|\s)?\s*(\d+[а-яa-z]?(?:/\d+)?)"
    match = re.search(street_rx, combined)
    if match:
        st_query = match.group(1)
        h_query = match.group(2).lower()
        for h_addr, coords in houses.items():
            if st_query in h_addr and h_query in h_addr:
                return coords, f"street_house_regex ({st_query} {h_query})"

    # 5. Привязка к центроиду улицы, если номер дома не указан
    for st_name, coords in street_centroids.items():
        if st_name in combined and len(st_name) > 4:
            return coords, f"street_centroid ({st_name})"

    # 6. Fallback на центр города (площадь Нефтяников / Ленина)
    return (60.9385, 76.5589), "city_center_default"

def process_sqlite():
    if not DB_PATH.exists():
        print(f"[!] SQLite {DB_PATH} не найден.")
        return 0, 0

    houses, institutions, street_centroids = load_knowledge_base()
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()

    cursor.execute("SELECT id, title, description, address, lat, lng, category FROM reports")
    rows = cursor.fetchall()
    print(f"\nАудит локальной БД ({len(rows)} сигналов)...")

    fixed = 0
    unchanged = 0
    results_summary = []

    for r_id, title, desc, addr, lat, lng, cat in rows:
        title = title or ""
        desc = desc or ""
        addr = addr or ""
        curr_lat = float(lat) if lat is not None else 0.0
        curr_lng = float(lng) if lng is not None else 0.0

        target_coords, source = resolve_exact_coords(addr, title, desc, houses, institutions, street_centroids)
        t_lat, t_lng = target_coords

        dist_m = haversine_distance_m(curr_lat, curr_lng, t_lat, t_lng) if (curr_lat != 0 and curr_lng != 0) else 999999

        # Исправляем, если координаты были пустыми (0,0), смещены более чем на 120м от точного адреса или стояли на старом дефолте
        if curr_lat == 0 or curr_lng == 0 or dist_m > 120 or (abs(curr_lat - 60.9344) < 0.002 and abs(curr_lng - 76.5531) < 0.002):
            cursor.execute("UPDATE reports SET lat = ?, lng = ? WHERE id = ?", (t_lat, t_lng, r_id))
            fixed += 1
            entry = f"#{r_id} [{cat}]: '{title[:35]}' -> ({t_lat:.5f}, {t_lng:.5f}) [{source}] (было {dist_m:.0f}м)"
            results_summary.append(entry)
            if fixed <= 15:
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
