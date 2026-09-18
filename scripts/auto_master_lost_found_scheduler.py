#!/usr/bin/env python3
"""
auto_master_lost_found_scheduler.py

Главный оркестратор и планировщик автопополнения «Бюро Находок / Потеряшек»
проекта «Пульс Города (Нижневартовск)».

Объединяет модули реального скрапинга:
  1. VK Public Scraper (vk_lost_found_scraper.py)
  2. Telegram Public Scraper (tg_lost_found_scraper.py)

auto_daily_lost_and_found_crawler.py исключён из планировщика: его
«источники» возвращали захардкоженные шаблоны с фейковыми адресами
и координатами, которые попадали в прод-БД.

Запуск:
  python scripts/auto_master_lost_found_scheduler.py --once
  python scripts/auto_master_lost_found_scheduler.py --cron --interval-hours 12
"""

import os
import sys
import time
import argparse
from datetime import datetime

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from scripts.vk_lost_found_scraper import run_vk_scraper
from scripts.tg_lost_found_scraper import run_tg_scraper

def run_all_sources(save_db=True):
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n========================================================")
    print(f"[{now_str}] МУЛЬТИ-ИСТОЧНИКОВЫЙ ЗАПУСК 'БЮРО НАХОДОК'")
    print(f"========================================================")

    total_saved = 0

    # 1. VK Scraper
    try:
        vk_count = run_vk_scraper(save_db=save_db)
        total_saved += vk_count
    except Exception as e:
        print(f"[ERROR VK] {e}")

    # 2. TG Scraper
    try:
        tg_count = run_tg_scraper(save_db=save_db)
        total_saved += tg_count
    except Exception as e:
        print(f"[ERROR TG] {e}")

    print(f"\n[ИТОГ] Завершен цикл сбора. Добавлено {total_saved} новых записей из реальных источников (VK, TG).")
    return total_saved

def main():
    parser = argparse.ArgumentParser(description="Главный планировщик автопополнения Бюро Находок.")
    parser.add_argument("--once", action="store_true", help="Однократный запуск всех скраперов.")
    parser.add_argument("--cron", action="store_true", help="Режим авто-планировщика в фоновом режиме.")
    parser.add_argument("--interval-hours", type=int, default=12, help="Интервал запуска в часах (по умолчанию 12ч).")
    args = parser.parse_args()

    if args.cron:
        print(f"[MASTER SCHEDULER] Фоновый режим активен. Интервал: {args.interval_hours} час(а/ов).")
        while True:
            run_all_sources(save_db=True)
            print(f"[WAIT] Ожидание следующего цикла ({args.interval_hours}ч)...")
            time.sleep(args.interval_hours * 3600)
    else:
        run_all_sources(save_db=True)

if __name__ == "__main__":
    main()
