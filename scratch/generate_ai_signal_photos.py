# scratch/generate_ai_signal_photos.py
import os
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

upload_dir = Path('c:/Soobshio_project/services/Backend/public/uploads/ai_generated')
upload_dir.mkdir(parents=True, exist_ok=True)

db = SessionLocal()
reports = db.query(Report).filter(Report.id >= 240).all()

CAT_COLORS = {
    'Потеряно животное': (245, 158, 11),    # Amber
    'Найдено животное': (16, 185, 129),     # Emerald Green
    'ЖКХ': (59, 130, 246),                  # Blue
    'Безопасность': (239, 68, 68),          # Red
    'Дороги': (139, 92, 246),               # Purple
    'Прочее': (107, 114, 128),              # Gray
}

for r in reports:
    clean_desc = re.sub(r'https?://[^\s]+', '', r.description or '').strip()
    accent = CAT_COLORS.get(r.category, (59, 130, 246))
    
    # Generate high-resolution 800x600 custom visual illustration frame
    img = Image.new('RGB', (800, 600), color=(15, 23, 42))
    draw = ImageDraw.Draw(img)
    
    # Draw background gradient
    for y in range(600):
        ratio = y / 600.0
        r_c = int(15 + (accent[0] - 15) * ratio * 0.35)
        g_c = int(23 + (accent[1] - 23) * ratio * 0.35)
        b_c = int(42 + (accent[2] - 42) * ratio * 0.35)
        draw.line([(0, y), (800, y)], fill=(r_c, g_c, b_c))

    # Outer neon border
    draw.rounded_rectangle([30, 30, 770, 570], radius=20, outline=accent, width=4)
    
    # Header card
    draw.rounded_rectangle([50, 50, 750, 140], radius=14, fill=(30, 41, 59))
    draw.text((70, 70), f"CITY PULSE SIGNAL #{r.id} [{r.category}]", fill=accent)
    draw.text((70, 98), f"Address: {r.address or 'Nizhnevartovsk'}", fill=(226, 232, 240))

    # Title & Content
    draw.rounded_rectangle([50, 160, 750, 550], radius=14, fill=(15, 23, 42))
    draw.text((70, 180), f"Title: {r.title}", fill=(255, 255, 255))
    
    lines = [clean_desc[i:i+60] for i in range(0, min(240, len(clean_desc)), 60)]
    y_off = 220
    for line in lines:
        draw.text((70, y_off), line, fill=(148, 163, 184))
        y_off += 28

    file_name = f"signal_{r.id}_ai.jpg"
    file_path = upload_dir / file_name
    img.save(file_path, quality=92)
    
    ai_photo_url = f"https://45-153-68-59.sslip.io/static/uploads/ai_generated/{file_name}"
    r.description = f"{clean_desc}\n\n{ai_photo_url}"
    print(f"Report #{r.id} updated with unique AI photo: {ai_photo_url}")

db.commit()
db.close()
print("All signal photos successfully generated and updated in DB!")
