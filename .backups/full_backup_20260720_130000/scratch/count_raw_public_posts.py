# scratch/count_raw_public_posts.py — Count total raw posts from Telegram & VK for today
import sys
import os
from datetime import datetime, timezone

sys.path.insert(0, r"c:\Soobshio_project\services\Backend")
sys.path.insert(0, r"c:\Soobshio_project")

from services.data_layer.database import SessionLocal
from sqlalchemy import text

def main():
    sys.stdout.reconfigure(encoding='utf-8')
    db = SessionLocal()
    try:
        # Check raw posts / telegram messages table or reports
        res = db.execute(text("SELECT count(*) FROM reports WHERE created_at >= CURRENT_DATE")).scalar()
        
        # Check if there's raw posts or telegram tables
        tables = db.execute(text("SELECT name FROM sqlite_master WHERE type='table'")).fetchall()
        table_names = [t[0] for t in tables]
        
        print("=== СТАТИСТИКА ВСЕХ ПОСТОВ ИЗ ПАБЛИКОВ НИЖНЕВАРТОВСКА ЗА СЕГОДНЯ ===")
        print("Существующие таблицы в БД:", table_names)
        
        if "telegram_posts" in table_names:
            tg_count = db.execute(text("SELECT count(*) FROM telegram_posts WHERE created_at >= CURRENT_DATE")).scalar()
            print(f"Всего сырых постов из Telegram-каналов: {tg_count}")
            
        if "vk_posts" in table_names:
            vk_count = db.execute(text("SELECT count(*) FROM vk_posts WHERE created_at >= CURRENT_DATE")).scalar()
            print(f"Всего сырых постов из VK-групп: {vk_count}")

        # Count total reports/signals created today
        total_reports = db.execute(text("SELECT count(*) FROM reports WHERE created_at >= CURRENT_DATE")).scalar()
        print(f"Всего создано сигналов на карте из этих постов: {total_reports}")

        # Get list of monitored channels
        channels = [
            "ЧП в Нижневартовске (@nv86chp)",
            "Типичный Нижневартовск (@nv_official)",
            "Привет, Нижневартовск! (@hello_nv)",
            "Нижневартовск ЭКСТРЕННО (@nv_emergency)",
            "Подслушано Нижневартовск (VK)",
            "Инцидент Нижневартовск (VK)",
            "ЧП Нижневартовск (VK)",
            "Официальный Нижневартовск (@nizhnevartovsk_official)"
        ]
        print(f"\nМониторинг ведётся по {len(channels)} пабликам Нижневартовска:")
        for c in channels:
            print(f"  • {c}")

    except Exception as e:
        print("Error checking raw posts:", e)
    finally:
        db.close()

if __name__ == "__main__":
    main()
