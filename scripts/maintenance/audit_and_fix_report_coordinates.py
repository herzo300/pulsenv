#!/usr/bin/env python3
"""
audit_and_fix_report_coordinates.py
Проверяет все адреса в сигналах (БД soobshio.db и локальные JSON-файлы),
сверяет с точным реестром зданий Нижневартовска (3450 домов + ориентиры)
и переносит сигналы с неверными/дефолтными координатами на точные координаты домов.
"""

import os
import sys
import json
import sqlite3
import re
import math
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT_DIR = Path(__file__).resolve().parents[2]
DB_PATH = ROOT_DIR / "soobshio.db"
HOUSES_JSON = ROOT_DIR / "services" / "Backend" / "data" / "nizhnevartovsk_houses.json"

# Canonical street and landmark coordinates
LANDMARKS = {
    "самотлор": (60.9398, 76.5652),
    "озеро комсомольское": (60.9450, 76.5500),
    "комсомольское озеро": (60.9450, 76.5500),
    "комсомольский бульвар": (60.9415, 76.5680),
    "сити центр": (60.9380, 76.5530),
    "югра молл": (60.9420, 76.5700),
    "автовокзал": (60.9410, 76.5730),
    "жд вокзал": (60.9560, 76.5850),
    "аэропорт": (60.9490, 76.4880),
    "площадь нефтяников": (60.9368, 76.5645),
    "администрация": (60.9370, 76.5530),
    "парк победы": (60.9400, 76.5480),
    "сквер строителей": (60.9310, 76.5560),
    "сквер космонавтов": (60.9320, 76.5750),
    "сквер матерей": (60.9470, 76.5880),
    "сквер героев самотлора": (60.9500, 76.6010),
    "ледовый дворец": (60.9420, 76.5650),
    "набережная": (60.9300, 76.5500),
    "старый вартовск": (60.9250, 76.5300),
    "рэб флота": (60.9150, 76.5900),
}

def haversine_distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def load_houses_registry():
    houses = {}
    if HOUSES_JSON.exists():
        try:
            with open(HOUSES_JSON, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for h in data:
                        addr = h.get("address", "").strip().lower()
                        if addr and "lat" in h and "lng" in h:
                            houses[addr] = (float(h["lat"]), float(h["lng"]))
        except Exception as e:
            print(f"Error loading houses JSON: {e}")
    return houses

def normalize_text(text: str) -> str:
    if not text:
        return ""
    t = text.lower().replace("ё", "е")
    t = re.sub(r"[,\.\(\)\"\']", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def resolve_exact_coordinates(address: str, title: str, description: str, houses: dict):
    combined = f"{address} {title} {description}".lower().replace("ё", "е")

    # 1. Exact match in houses registry
    norm_addr = normalize_text(address)
    if norm_addr in houses:
        return houses[norm_addr], "exact_house"

    for h_addr, coords in houses.items():
        if h_addr in norm_addr or (len(h_addr) > 5 and h_addr in combined):
            return coords, "registry_match"

    # 2. Match street + house number regex
    street_match = re.search(r"(ленина|мира|интернациональн\w*|чапаев\w*|дзержинск\w*|ханты-мансийск\w*|60 лет октября|побед\w*|кузоваткин\w*|нефтяник\w*|дружбы народов|северн\w*|омск\w*|менделеев\w*|спортивн\w*|пермск\w*|героев самотлор\w*|маршала жуков\w*|жуков\w*|индустриальн\w*|авиатор\w*|лопарев\w*|лесн\w*|рабоч\w*|таежн\w*|школьн\w*|заводск\w*|пикман\w*|рощинск\w*|куропаткин\w*|заозерн\w*)\s*(?:дом|д\.)?\s*(\d+[а-яa-z]?(?:/\d+)?)", combined)
    if street_match:
        st_name = street_match.group(1)
        h_num = street_match.group(2).lower()
        for h_addr, coords in houses.items():
            if st_name in h_addr and h_num in h_addr:
                return coords, f"street_house_match ({st_name} {h_num})"

    # 3. Match landmarks
    for lm, coords in LANDMARKS.items():
        if lm in combined:
            return coords, f"landmark ({lm})"

    return None, "unresolved"

def audit_and_fix_database():
    if not DB_PATH.exists():
        print(f"[ERROR] Database {DB_PATH} not found.")
        return

    houses = load_houses_registry()
    print(f"Loaded {len(houses)} authoritative building coordinates for Nizhnevartovsk.")

    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()

    # Check reports table structure
    cursor.execute("PRAGMA table_info(reports)")
    cols = [c[1] for c in cursor.fetchall()]
    print(f"Reports columns: {cols}")

    cursor.execute("SELECT id, title, description, address, lat, lng FROM reports")
    rows = cursor.fetchall()
    print(f"Total reports in database: {len(rows)}")

    fixed_count = 0
    correct_count = 0
    unresolved_count = 0

    for r_id, title, desc, addr, lat, lng in rows:
        title_str = title or ""
        desc_str = desc or ""
        addr_str = addr or ""
        curr_lat = float(lat) if lat is not None else 0.0
        curr_lng = float(lng) if lng is not None else 0.0

        target_coords, source = resolve_exact_coordinates(addr_str, title_str, desc_str, houses)

        if target_coords:
            t_lat, t_lng = target_coords
            dist_m = haversine_distance_m(curr_lat, curr_lng, t_lat, t_lng) if (curr_lat != 0 and curr_lng != 0) else 999999

            # If current coordinates are (0,0), off by > 350m, or at default center while specific house is known:
            if curr_lat == 0 or curr_lng == 0 or dist_m > 350 or (abs(curr_lat - 60.9344) < 0.001 and abs(curr_lng - 76.5531) < 0.001 and dist_m > 50):
                cursor.execute(
                    "UPDATE reports SET lat = ?, lng = ? WHERE id = ?",
                    (t_lat, t_lng, r_id)
                )
                fixed_count += 1
                print(f"  [FIXED] Report #{r_id}: '{title_str[:40]}' | Addr: '{addr_str}' -> ({t_lat:.5f}, {t_lng:.5f}) via {source} (was {dist_m:.0f}m away)")
            else:
                correct_count += 1
        else:
            unresolved_count += 1

    conn.commit()
    conn.close()

    print("\n" + "=" * 60)
    print(f"  ИТОГИ АУДИТА И КОРРЕКЦИИ ГЕОКООРДИНАТ СИГНАЛОВ:")
    print(f"  ✓ Корректных сигналов (остались на месте): {correct_count}")
    print(f"  ⚡ Исправлено и перенесено на точные адреса: {fixed_count}")
    print(f"  ℹ️ Сигналов без привязки к конкретному дому: {unresolved_count}")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    audit_and_fix_database()
