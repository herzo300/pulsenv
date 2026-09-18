#!/usr/bin/env python3
"""
regeocode_reports_exact.py
Пересаживает ВСЕ маркеры reports строго по координатам:
реальные данные Nominatim/OSM (дом → улица → перекрёсток) → локальная база
(только офлайн-фолбэк) → центр нужного города.
Делает бэкап БД перед изменениями и печатает итоговую таблицу.
"""
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from services.Backend.comprehensive_marker_geofix import (  # noqa: E402
    DB_PATH, process_sqlite,
)


def main() -> None:
    if not DB_PATH.exists():
        print(f"[!] БД не найдена: {DB_PATH}")
        sys.exit(1)

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = DB_PATH.with_suffix(f".backup_{stamp}.db")
    shutil.copy2(DB_PATH, backup)
    print(f"✓ Бэкап БД: {backup}")

    fixed, unchanged, summary = process_sqlite()

    conn = sqlite3.connect(str(DB_PATH))
    rows = conn.execute(
        "SELECT id, title, address, lat, lng, city FROM reports ORDER BY id"
    ).fetchall()
    conn.close()

    print("\nИТОГОВАЯ РАСКЛАДКА МАРКЕРОВ")
    print("-" * 96)
    for r_id, title, addr, lat, lng, city in rows:
        print(f"#{r_id:<4} {(city or '?'):14s} {float(lat):.5f},{float(lng):.5f}  {(addr or title or '')[:48]}")
    print("-" * 96)
    print(f"Всего: {len(rows)} | исправлено: {fixed} | без изменений: {unchanged}")


if __name__ == "__main__":
    main()
