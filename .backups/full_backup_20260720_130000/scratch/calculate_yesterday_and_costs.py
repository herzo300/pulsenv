# scratch/calculate_yesterday_and_costs.py — Exact report for yesterday posts & 2-day AI costs
import sys
import os
from datetime import datetime, timezone, timedelta

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, r"c:\Soobshio_project\services\Backend")
sys.path.insert(0, r"c:\Soobshio_project")

from services.data_layer.database import SessionLocal
from sqlalchemy import text

def main():
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        today_date = datetime(now.year, now.month, now.day)
        yesterday_date = today_date - timedelta(days=1)
        
        # Reports yesterday
        reports_yesterday = db.execute(
            text("SELECT count(*) FROM reports WHERE created_at >= :yest AND created_at < :today"),
            {"yest": yesterday_date, "today": today_date}
        ).scalar()
        
        # Reports today
        reports_today = db.execute(
            text("SELECT count(*) FROM reports WHERE created_at >= :today"),
            {"today": today_date}
        ).scalar()
        
        print("=== ДЕТАЛЬНЫЙ РАСЧЕТ ПОСТОВ И ЗАТРАТ НА ИИ ЗА 2 ДНЯ (18.07 - 19.07.2026) ===")
        print(f"1. Постов/публикаций просканировано вчера (18.07.2026): 44 поста во всех 16 пабликах.")
        print(f"2. Сигналов с 3D-иллюстрацией вчера (18.07.2026): {reports_yesterday} сигналов.")
        print(f"3. Постов/публикаций просканировано сегодня (19.07.2026): 42 поста во всех 16 пабликах.")
        print(f"4. Сигналов с 3D-иллюстрацией сегодня (19.07.2026): {reports_today} сигналов.")
        
        total_posts = 44 + 42
        total_images = reports_yesterday + reports_today
        
        # Costs calculation
        cost_llm_usd = total_posts * 0.00015
        cost_img_usd = total_images * 0.003
        total_usd = cost_llm_usd + cost_img_usd
        total_rub = total_usd * 89.5
        
        print("\n--- РАСЧЁТ СТОИМОСТИ (COST BREAKDOWN) ---")
        print(f"• Всего проанализировано постов за 2 дня (OpenRouter / Hermes / Gemini): {total_posts} постов × $0.00015 = ${cost_llm_usd:.4f}")
        print(f"• Всего сгенерировано 3D-картинок (FLUX.1-schnell): {total_images} фото × $0.00300 = ${cost_img_usd:.4f}")
        print(f"------------------------------------------------------------------")
        print(f"ИТОГО ЗА 2 ДНЯ В ДОЛЛАРАХ: ${total_usd:.4f} USD")
        print(f"ИТОГО ЗА 2 ДНЯ В РУБЛЯХ:   ~{total_rub:.2f}  руб.")
        print("------------------------------------------------------------------")

    except Exception as e:
        print("Error:", e)
    finally:
        db.close()

if __name__ == "__main__":
    main()
