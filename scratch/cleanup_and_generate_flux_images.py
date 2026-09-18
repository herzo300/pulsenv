# scratch/cleanup_and_generate_flux_images.py — Clean old signals (>3 days) & generate individual FLUX images
import sys
import os
import asyncio
from datetime import datetime, timedelta

sys.path.insert(0, r"c:\Soobshio_project")

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report
from services.Backend.services.ai.flux_image_service import generate_signal_image_flux

async def main():
    db = SessionLocal()
    try:
        # 1. Delete reports older than 3 days
        three_days_ago = datetime.utcnow() - timedelta(days=3)
        deleted_count = db.query(Report).filter(Report.created_at < three_days_ago).delete()
        db.commit()
        print(f"Deleted {deleted_count} reports older than 3 days.")

        # 2. Fetch all remaining active reports
        reports = db.query(Report).all()
        print(f"Active reports remaining: {len(reports)}")

        # 3. Generate FLUX 3D image for each report without photo
        updated_count = 0
        for report in reports:
            desc = report.description or ""
            if "Фото:" not in desc and "http" not in desc:
                title = report.title or report.category or "Сигнал"
                cat = report.category or "ЖКХ"
                img_url = await generate_signal_image_flux(title, cat, desc[:150])
                if img_url:
                    report.description = f"{desc}\nФото: {img_url}".strip()
                    updated_count += 1
                    print(f"Generated FLUX image for Report #{report.id} ({title}): {img_url[:60]}...")
                await asyncio.sleep(0.3)

        db.commit()
        print(f"Successfully generated individual FLUX images for {updated_count} signals.")

    except Exception as e:
        print(f"Error during cleanup & image generation: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(main())
