import os
import sys
from datetime import datetime

# Add project root to python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

YESTERDAY_REPORTS = [
    {
        "title": "Потерян ошейник с адресником",
        "description": "Вчера вечером в районе сквера Космонавтов потерян красный кожаный ошейник с адресником на имя Арчи. Просьба вернуть за вознаграждение.",
        "category": "Потеряно животное",
        "address": "ул. Ленина 15, Нижневартовск",
        "lat": 60.9378,
        "lng": 76.5712,
        "source": "vk:lost_pets_nv",
        "telegram_channel": "Потеряшки Нижневартовск"
    },
    {
        "title": "Найдена детская перчатка",
        "description": "На детской площадке по адресу Ленина 15 найдена теплая детская перчатка синего цвета. Оставили на качелях.",
        "category": "Найдена вещь",
        "address": "ул. Ленина 15, Нижневартовск",
        "lat": 60.9380,
        "lng": 76.5715,
        "source": "tg:@podslushano_dogs_nv",
        "telegram_channel": "Животные НВ"
    },
    {
        "title": "Прорыв трубы отопления",
        "description": "Во дворе дома прорыв горячей воды на теплотрассе. Горячий пар валит из колодца. Вода течет рекой по тротуару.",
        "category": "ЖКХ",
        "address": "ул. Дружбы Народов 15, Нижневартовск",
        "lat": 60.9442,
        "lng": 76.5910,
        "source": "user_report",
        "telegram_channel": None
    },
    {
        "title": "Опасная выбоина на дороге",
        "description": "На проезжей части образовалась глубокая яма с острыми краями. Водители вынуждены выезжать на встречную полосу, чтобы объехать.",
        "category": "Дороги",
        "address": "проспект Победы 10, Нижневартовск",
        "lat": 60.9351,
        "lng": 76.5621,
        "source": "user_report",
        "telegram_channel": None
    },
    {
        "title": "Найдены ключи от квартиры с брелоком-котом",
        "description": "В районе дома Чапаева 9 найдена связка ключей (3 штуки) на металлическом кольце с резиновым брелоком в виде серого кота.",
        "category": "Найдена вещь",
        "address": "ул. Чапаева 9, Нижневартовск",
        "lat": 60.9325,
        "lng": 76.5898,
        "source": "vk:bureau_nv",
        "telegram_channel": "Бюро находок"
    }
]

def seed_yesterday():
    db = SessionLocal()
    try:
        inserted = 0
        yesterday = datetime(2026, 7, 9, 14, 30, 0)
        
        for item in YESTERDAY_REPORTS:
            # Check if already seeded
            exists = db.query(Report).filter(
                Report.title == item["title"],
                Report.address == item["address"]
            ).first()
            if exists:
                print(f"Запись '{item['title']}' уже существует в базе.")
                continue
                
            report = Report(
                title=item["title"],
                description=item["description"],
                lat=item["lat"],
                lng=item["lng"],
                address=item["address"],
                category=item["category"],
                status="open",
                source=item["source"],
                telegram_channel=item["telegram_channel"],
                supporters=0,
                supporters_notified=0,
                likes_count=0,
                dislikes_count=0,
                created_at=yesterday,
                updated_at=yesterday
            )
            db.add(report)
            inserted += 1
            
        db.commit()
        print(f"Успешно добавлено {inserted} вчерашних сигналов на карту Нижневартовска.")
    except Exception as e:
        db.rollback()
        print(f"Ошибка при импорте: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_yesterday()
