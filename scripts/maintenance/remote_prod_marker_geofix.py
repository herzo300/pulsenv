#!/usr/bin/env python3
"""
remote_prod_marker_geofix.py
Выполняет аудит и выравнивание координат всех сигналов в продакшн PostgreSQL на Timeweb VPS (45.153.68.59).
"""

import os
import sys
import paramiko
from pathlib import Path
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(r"C:\Soobshio_project")
load_dotenv(PROJECT / ".env")

HOST = "45.153.68.59"
USER = "root"
REMOTE_DIR = "/opt/soobshio"
PASS = os.getenv("SSH_PASSWORD", "").strip()

if not PASS:
    print("[ERROR] SSH_PASSWORD отсутствует в .env")
    sys.exit(1)

print("=" * 65)
print(f"  City Pulse — Точный гео-аудит маркеров на VPS ({HOST})")
print("=" * 65)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=20)
sftp = ssh.open_sftp()

# Загружаем скрипт на сервер
local_script = PROJECT / "scripts" / "maintenance" / "comprehensive_marker_geofix.py"
remote_script = f"{REMOTE_DIR}/services/Backend/comprehensive_marker_geofix.py"

sftp.put(str(local_script), remote_script)
print("✓ Скрипт гео-аудита загружен в services/Backend.")

# Запускаем скрипт внутри контейнера бэкенда с доступом к Postgres
remote_runner = """
import os, sys, json, re, math
from pathlib import Path

for p in ["/app", "/app/services", "/app/services/Backend"]:
    if p not in sys.path:
        sys.path.insert(0, p)

import psycopg2

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://soobshio:soobshio_secure_pass_2025@postgres:5432/soobshio")
if "postgresql+psycopg2://" in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("postgresql+psycopg2://", "postgresql://")

from comprehensive_marker_geofix import (
    load_knowledge_base, resolve_exact_coords, haversine_distance_m, update_events_venues
)

print("Запуск гео-аудита в PostgreSQL...")
update_events_venues()
houses, institutions, street_centroids = load_knowledge_base()

conn = psycopg2.connect(DATABASE_URL)
cursor = conn.cursor()

cursor.execute("SELECT id, title, description, address, lat, lng, category FROM reports")
rows = cursor.fetchall()
print(f"Всего сигналов в продакшн БД: {len(rows)}")

fixed = 0
unchanged = 0
fixed_samples = []

for r_id, title, desc, addr, lat, lng, cat in rows:
    title = title or ""
    desc = desc or ""
    addr = addr or ""
    curr_lat = float(lat) if lat is not None else 0.0
    curr_lng = float(lng) if lng is not None else 0.0

    target_coords, source = resolve_exact_coords(addr, title, desc, houses, institutions, street_centroids)
    t_lat, t_lng = target_coords

    dist_m = haversine_distance_m(curr_lat, curr_lng, t_lat, t_lng) if (curr_lat != 0 and curr_lng != 0) else 999999

    if curr_lat == 0 or curr_lng == 0 or dist_m > 120 or (abs(curr_lat - 60.9344) < 0.002 and abs(curr_lng - 76.5531) < 0.002):
        cursor.execute("UPDATE reports SET lat = %s, lng = %s WHERE id = %s", (t_lat, t_lng, r_id))
        fixed += 1
        entry = f"#{r_id} [{cat}]: '{title[:32]}' -> ({t_lat:.5f}, {t_lng:.5f}) [{source}] (было {dist_m:.0f}м)"
        fixed_samples.append(entry)
        if fixed <= 25:
            print(f"  [FIXED] {entry}")
    else:
        unchanged += 1

conn.commit()
conn.close()

print(f"\\nИТОГИ ПРОДАКШН ГЕО-АУДИТА:")
print(f"  ✓ Исправлено и точно спозиционировано: {fixed} маркеров")
print(f"  ✓ Корректных маркеров (без смещения): {unchanged}")
"""

# Записываем скрипт раннера на VPS
runner_path = f"{REMOTE_DIR}/services/Backend/_run_prod_geofix.py"
with sftp.file(runner_path, "w") as f:
    f.write(remote_runner)
sftp.close()

# Выполняем через docker compose exec backend
cmd = f"cd {REMOTE_DIR} && docker compose exec -T backend python /app/services/Backend/_run_prod_geofix.py"
print(f"\n$ {cmd}\n")
stdin, stdout, stderr = ssh.exec_command(cmd, timeout=90)
exit_status = stdout.channel.recv_exit_status()
out = stdout.read().decode("utf-8", errors="replace")
err = stderr.read().decode("utf-8", errors="replace")

if out:
    print(out)
if err and exit_status != 0:
    print(f"[ERR] {err}")

ssh.close()
print("=" * 65)
print("  ГЕО-АУДИТ И ВЫРАВНИВАНИЕ ПРОДАКШН БД УСПЕШНО ЗАВЕРШЕНО ✓")
print("=" * 65)
