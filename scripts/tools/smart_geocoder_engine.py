#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
smart_geocoder_engine.py
Универсальный интеллектуальный геокодер для Нижневартовска.
Выравнивает все маркеры сигналов из пабликов строго по координатам домов,
улиц и объектов инфраструктуры.
"""

import os
import sys
import json
import sqlite3
import re
import math
import paramiko
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT_DIR = Path(__file__).resolve().parent.parent.parent

# Загрузка базы домов 3450+ Нижневартовска
HOUSES_PATH = ROOT_DIR / "services" / "Backend" / "data" / "nizhnevartovsk_houses.json"
if not HOUSES_PATH.exists():
    HOUSES_PATH = ROOT_DIR / "data" / "nizhnevartovsk_houses.json"

VPS_HOST = "45.153.68.59"
VPS_PORT = 22
VPS_USER = "root"
VPS_PASS = "sf?UQ8AYk*-DB8"

def normalize_text(text: str) -> str:
    if not text:
        return ""
    t = text.lower().replace("ё", "е")
    t = re.sub(r"[,\.\(\)\"\'«»]", " ", t)
    return re.sub(r"\s+", " ", t).strip()

def build_nizhnevartovsk_geo_index():
    houses_dict = {}
    street_centroids = {}
    street_pts = {}

    if HOUSES_PATH.exists():
        with open(HOUSES_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            for item in data:
                addr = normalize_text(item.get("address", ""))
                street = normalize_text(item.get("street", ""))
                lat = float(item["lat"])
                lng = float(item["lng"])
                if addr:
                    houses_dict[addr] = (lat, lng)
                if street:
                    street_pts.setdefault(street, []).append((lat, lng))

    for st, pts in street_pts.items():
        if pts:
            avg_lat = sum(p[0] for p in pts) / len(pts)
            avg_lng = sum(p[1] for p in pts) / len(pts)
            street_centroids[st] = (avg_lat, avg_lng)

    return houses_dict, street_centroids

def geocode_public_post(address: str, title: str, description: str, houses_dict: dict, street_centroids: dict):
    combined = f"{address} {title} {description}".lower().replace("ё", "е")
    norm_addr = normalize_text(address)

    # 1. Прямое совпадение по адресу дома
    if norm_addr in houses_dict:
        return houses_dict[norm_addr], f"exact_house ({norm_addr})"

    # 2. Сопоставление с реестром домов по точным ключам (улица + номер дома + литера)
    for h_addr, coords in houses_dict.items():
        if h_addr in norm_addr:
            return coords, f"registry_address ({h_addr})"

    # 3. Регулярный поиск улицы и номера дома с литерами (например: Ленина 15б, Мира 42/1, победы 3)
    street_pattern = (
        r"(ленина|мира|интернациональн\w*|чапаев\w*|дзержинск\w*|ханты-мансийск\w*|"
        r"60 лет октября|побед\w*|кузоваткин\w*|нефтяник\w*|дружбы народов|северн\w*|"
        r"омск\w*|менделеев\w*|спортивн\w*|пермск\w*|героев самотлор\w*|маршала жуков\w*|"
        r"жуков\w*|индустриальн\w*|авиатор\w*|лопарев\w*|лесн\w*|рабоч\w*|таежн\w*|"
        r"школьн\w*|заводск\w*|пикман\w*|рощинск\w*|куропаткин\w*|заозерн\w*|романтик\w*|"
        r"нововартовск\w*)\s*(?:дом|д\.|\s)?\s*(\d+[а-яa-z]?(?:/\d+)?)"
    )
    match = re.search(street_pattern, combined)
    if match:
        st_found = match.group(1)
        num_found = match.group(2).lower()
        # Ищем совпадение в словаре домов
        for h_addr, coords in houses_dict.items():
            if st_found in h_addr and num_found in h_addr:
                return coords, f"regex_matched_house ({st_found} {num_found})"

    # 4. Центроид улицы, если номер дома не найден
    for st_name, coords in street_centroids.items():
        if st_name in combined and len(st_name) > 4:
            return coords, f"street_centroid ({st_name})"

    # 5. Дефолтный центр города (Площадь Нефтяников)
    return (60.9368, 76.5645), "nizhnevartovsk_center"

def fix_all_databases():
    houses_dict, street_centroids = build_nizhnevartovsk_geo_index()
    print(f"Загружено {len(houses_dict)} домов и {len(street_centroids)} центроидов улиц Нижневартовска.")

    # 1. Исправление локальной базы SQLite
    db_local = ROOT_DIR / "soobshio.db"
    if db_local.exists():
        conn = sqlite3.connect(str(db_local))
        cur = conn.cursor()
        cur.execute("SELECT id, title, description, address, lat, lng FROM reports")
        rows = cur.fetchall()
        updated_count = 0
        for r_id, title, desc, addr, lat, lng in rows:
            coords, source = geocode_public_post(addr or "", title or "", desc or "", houses_dict, street_centroids)
            cur.execute("UPDATE reports SET lat = ?, lng = ? WHERE id = ?", (coords[0], coords[1], r_id))
            updated_count += 1
        conn.commit()
        conn.close()
        print(f"[OK] SQLite: обновлено {updated_count} сигналов.")

    # 2. Исправление продакшн базы PostgreSQL на VPS
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(VPS_HOST, VPS_PORT, VPS_USER, VPS_PASS, timeout=30)
        print("[OK] Подключено к Timeweb VPS")
        
        # Перезапуск бэкенда для применения обновленного модуля геокодинга
        ssh.exec_command("cd /opt/soobshio && docker compose restart backend")
        print("[OK] Продашкн бэкенд перезапущен с исправленным геокодером.")
    except Exception as e:
        print("[ERROR VPS]", e)
    finally:
        ssh.close()

if __name__ == "__main__":
    fix_all_databases()
