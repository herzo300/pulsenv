# scratch/count_today_posts.py — Calculate exact count of today posts & signals
import sys
import os
from datetime import datetime, timezone, timedelta

sys.path.insert(0, r"c:\Soobshio_project\services\Backend")
sys.path.insert(0, r"c:\Soobshio_project")

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

def main():
    db = SessionLocal()
    try:
        # Today date (19.07.2026)
        now_utc = datetime.now(timezone.utc)
        start_of_today = datetime(now_utc.year, now_utc.month, now_utc.day)
        
        all_reports = db.query(Report).filter(Report.created_at >= start_of_today).all()
        total_today = len(all_reports)

        categories = {}
        for r in all_reports:
            cat = r.category or "Прочее"
            categories[cat] = categories.get(cat, 0) + 1

        print("=== СТАТИСТИКА СИГНАЛОВ И ПОСТОВ ЗА СЕГОДНЯ (19.07.2026) ===")
        print(f"Общее количество уникальных постов/сигналов из пабликов за сегодня: {total_today}")
        print("\nРаскладка по категориям:")
        for cat, count in categories.items():
            print(f"  • {cat}: {count}")

    except Exception as e:
        print(f"Error counting today posts: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
