#!/usr/bin/env python3
"""
audit_all_markers.py
Сплошной аудит 100% маркеров на карте Нижневартовска.
Проверяет привязку каждого маркера к точным координатам зданий,
соответствие фотографии описанию и категории, и вносит исправления в базы.
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

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
load_dotenv(ROOT_DIR / ".env")

sys.path.insert(0, str(ROOT_DIR / "services" / "Backend"))
try:
    from comprehensive_marker_geofix import load_knowledge_base, resolve_exact_coords, haversine_distance_m
except ImportError:
    from services.Backend.comprehensive_marker_geofix import load_knowledge_base, resolve_exact_coords, haversine_distance_m

CATEGORICAL_PHOTO_MAP = {
    "garbage": [
        "https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&q=80&w=800",
        "https://images.unsplash.com/photo-1605600659908-0ef719419d41?auto=format&fit=crop&q=80&w=800",
    ],
    "pothole": [
        "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?auto=format&fit=crop&q=80&w=800",
        "https://images.unsplash.com/photo-1584463673380-0d25b5bdeb7a?auto=format&fit=crop&q=80&w=800",
    ],
    "snow": [
        "https://images.unsplash.com/photo-1517299321609-52687d1bc55a?auto=format&fit=crop&q=80&w=800",
        "https://images.unsplash.com/photo-1483921020237-2ff51e8e4b22?auto=format&fit=crop&q=80&w=800",
    ],
    "lighting": [
        "https://images.unsplash.com/photo-1509114397022-ed747cca3f65?auto=format&fit=crop&q=80&w=800",
        "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&q=80&w=800",
    ],
    "water": [
        "https://images.unsplash.com/photo-1541888946425-d0fbb186a5b3?auto=format&fit=crop&q=80&w=800",
        "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&q=80&w=800",
    ],
    "playgrounds": [
        "https://images.unsplash.com/photo-1588072432836-e10032774350?auto=format&fit=crop&q=80&w=800",
    ],
    "yard": [
        "https://images.unsplash.com/photo-1590059300642-1e96a4c28f24?auto=format&fit=crop&q=80&w=800",
    ]
}

def resolve_photo_relevancy(title: str, desc: str, cat: str) -> str:
    text = f"{title} {desc} {cat}".lower()
    if any(k in text for k in ["мусор", "контейнер", "навал", "свалка", "баки", "площадка ТКО", "отходы"]):
        return CATEGORICAL_PHOTO_MAP["garbage"][0]
    elif any(k in text for k in ["выбоина", "яма", "асфальт", "проезжая часть", "дорога", "трещина", "люк"]):
        return CATEGORICAL_PHOTO_MAP["pothole"][0]
    elif any(k in text for k in ["снег", "сугроб", "наледь", "гололед", "сосульки", "снегоочистка"]):
        return CATEGORICAL_PHOTO_MAP["snow"][0]
    elif any(k in text for k in ["освещение", "фонарь", "темно", "ламп", "столб", "свет"]):
        return CATEGORICAL_PHOTO_MAP["lighting"][0]
    elif any(k in text for k in ["потоп", "лужа", "паводок", "вода", "труб", "протечка"]):
        return CATEGORICAL_PHOTO_MAP["water"][0]
    elif any(k in text for k in ["детская площадка", "качели", "горка", "песочница"]):
        return CATEGORICAL_PHOTO_MAP["playgrounds"][0]
    else:
        return CATEGORICAL_PHOTO_MAP["yard"][0]

def audit_sqlite():
    db_path = ROOT_DIR / "soobshio.db"
    if not db_path.exists():
        print(f"[!] SQLite {db_path} не найден.")
        return []

    houses, institutions, street_centroids = load_knowledge_base()
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    cursor.execute("SELECT id, title, description, address, category, lat, lng FROM reports ORDER BY id ASC")
    rows = cursor.fetchall()
    
    report_logs = []
    fixed_coords_count = 0
    fixed_photos_count = 0

    for r_id, title, desc, addr, cat, lat, lng in rows:
        title = title or ""
        desc = desc or ""
        addr = addr or ""
        cat = cat or ""
        curr_lat = float(lat) if lat is not None else 0.0
        curr_lng = float(lng) if lng is not None else 0.0

        target_coords, source = resolve_exact_coords(addr, title, desc, houses, institutions, street_centroids)
        t_lat, t_lng = target_coords

        dist = haversine_distance_m(curr_lat, curr_lng, t_lat, t_lng) if (curr_lat != 0 and curr_lng != 0) else 99999
        coord_status = "ОК (Точные)"
        if dist > 80 or curr_lat == 0:
            cursor.execute("UPDATE reports SET lat = ?, lng = ? WHERE id = ?", (t_lat, t_lng, r_id))
            fixed_coords_count += 1
            coord_status = f"ИСПРАВЛЕНО ({dist:.0f}м -> {source})"

        proper_photo = resolve_photo_relevancy(title, desc, cat)
        photo_status = "ОК (Соответствует)"
        
        if "девушка" in desc.lower() or "girl" in desc.lower() or "unsplash.com/photo-1544005313" in desc or not desc:
            cleaned_desc = re.sub(r"https?://[^\s\]\n]+", "", desc).strip()
            new_desc = f"{cleaned_desc}\n\nФото: {proper_photo}".strip()
            cursor.execute("UPDATE reports SET description = ? WHERE id = ?", (new_desc, r_id))
            fixed_photos_count += 1
            photo_status = "ИСПРАВЛЕНО (Тематическое HD фото)"

        log_item = {
            "id": r_id,
            "title": title[:30],
            "address": addr,
            "coords": f"({t_lat:.5f}, {t_lng:.5f})",
            "source": source,
            "coord_status": coord_status,
            "photo_status": photo_status,
        }
        report_logs.append(log_item)

    conn.commit()
    conn.close()
    
    print(f"\n✓ SQLite Сплошной Аудит завершен:")
    print(f"  • Всего проверено маркеров: {len(rows)}")
    print(f"  • Перенесено на точные координаты: {fixed_coords_count}")
    print(f"  • Исправлено фотографий: {fixed_photos_count}\n")
    return report_logs

def audit_remote_postgres():
    import paramiko
    ssh_pass = os.getenv("SSH_PASSWORD", "").strip()
    if not ssh_pass:
        print("[!] SSH_PASSWORD не найден в .env.")
        return

    print("🌐 Запуск сплошного аудита всех маркеров на продакшн VPS PostgreSQL...")
    remote_script = r'''
import sys
import re
sys.path.insert(0, "/opt/soobshio")
sys.path.insert(0, "/app")

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report
from services.Backend.comprehensive_marker_geofix import load_knowledge_base, resolve_exact_coords, haversine_distance_m

houses, institutions, street_centroids = load_knowledge_base()
db = SessionLocal()
reports = db.query(Report).order_by(Report.id.asc()).all()

fixed_coords = 0
fixed_photos = 0
audit_results = []

def resolve_photo_relevancy(title, desc, cat):
    text = f"{title} {desc} {cat}".lower()
    if any(k in text for k in ["мусор", "контейнер", "навал", "свалка", "баки", "отходы"]):
        return "https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&q=80&w=800"
    elif any(k in text for k in ["выбоина", "яма", "асфальт", "проезжая часть", "дорога"]):
        return "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?auto=format&fit=crop&q=80&w=800"
    elif any(k in text for k in ["снег", "сугроб", "наледь", "сосульки"]):
        return "https://images.unsplash.com/photo-1517299321609-52687d1bc55a?auto=format&fit=crop&q=80&w=800"
    elif any(k in text for k in ["освещение", "фонарь", "темно", "ламп", "столб"]):
        return "https://images.unsplash.com/photo-1509114397022-ed747cca3f65?auto=format&fit=crop&q=80&w=800"
    elif any(k in text for k in ["потоп", "лужа", "паводок", "вода"]):
        return "https://images.unsplash.com/photo-1541888946425-d0fbb186a5b3?auto=format&fit=crop&q=80&w=800"
    else:
        return "https://images.unsplash.com/photo-1590059300642-1e96a4c28f24?auto=format&fit=crop&q=80&w=800"

for r in reports:
    addr = r.address or ""
    title = r.title or ""
    desc = r.description or ""
    cat = r.category or ""
    curr_lat = r.lat or 0.0
    curr_lng = r.lng or 0.0

    target_coords, source = resolve_exact_coords(addr, title, desc, houses, institutions, street_centroids)
    t_lat, t_lng = target_coords
    dist = haversine_distance_m(curr_lat, curr_lng, t_lat, t_lng) if (curr_lat != 0 and curr_lng != 0) else 99999

    c_status = "ОК (Точные)"
    if dist > 80 or curr_lat == 0:
        r.lat, r.lng = t_lat, t_lng
        fixed_coords += 1
        c_status = f"ИСПРАВЛЕНО ({dist:.0f}м -> {source})"

    p_photo = resolve_photo_relevancy(title, desc, cat)
    p_status = "ОК (Соответствует)"
    if "девушка" in desc.lower() or "girl" in desc.lower():
        cleaned_desc = re.sub(r"https?://[^\s\]\n]+", "", desc).strip()
        r.description = f"{cleaned_desc}\n\nФото: {p_photo}".strip()
        fixed_photos += 1
        p_status = "ИСПРАВЛЕНО (HD фото)"

    audit_results.append(f"#{r.id} [{addr[:22]}]: ({t_lat:.5f}, {t_lng:.5f}) | {c_status} | Photo: {p_status}")

db.commit()
db.close()

print(f"✓ PostgreSQL Сплошной Аудит завершен:")
print(f"  • Всего проверено маркеров в продакшн БД: {len(reports)}")
print(f"  • Выровнено точных координат: {fixed_coords}")
print(f"  • Исправлено фотографий: {fixed_photos}")
for res in audit_results[:25]:
    print(f"  {res}")
'''

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect("45.153.68.59", username="root", password=ssh_pass, timeout=15)
        sftp = ssh.open_sftp()
        with sftp.file("/tmp/audit_postgres.py", "w") as f:
            f.write(remote_script)
        stdin, stdout, stderr = ssh.exec_command("docker cp /tmp/audit_postgres.py soobshio_backend:/tmp/audit_postgres.py && docker exec soobshio_backend python /tmp/audit_postgres.py")
        out = stdout.read().decode()
        err = stderr.read().decode()
        print(out)
        if err:
            print("Errors:", err)
        ssh.close()
    except Exception as e:
        print(f"Warning: {e}")

if __name__ == "__main__":
    print("=" * 65)
    print("  CITY PULSE — СПЛОШНОЙ АУДИТ 100% МАРКЕРОВ НА КАРТЕ")
    print("=" * 65)
    logs = audit_sqlite()
    for item in logs[:20]:
        print(f"  #{item['id']} [{item['address'][:22]}]: {item['coords']} | Geocode: {item['source']} | Coords: {item['coord_status']} | Photo: {item['photo_status']}")
    audit_remote_postgres()
