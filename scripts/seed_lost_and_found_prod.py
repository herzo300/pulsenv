import os
import sys
import random
from datetime import datetime, timedelta

# Добавляем корень проекта в пути импорта
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

# Координаты Нижневартовска
LOCATIONS = [
    {"address": "ул. Героев Самотлора 20, Нижневартовск", "lat": 60.9412, "lng": 76.6185},
    {"address": "ул. Ленина 15, Нижневартовск", "lat": 60.9378, "lng": 76.5712},
    {"address": "ул. Дружбы Народов 15, Нижневартовск", "lat": 60.9442, "lng": 76.5910},
    {"address": "ул. Мира 60, Нижневартовск", "lat": 60.9431, "lng": 76.5824},
    {"address": "ул. Чапаева 9, Нижневартовск", "lat": 60.9325, "lng": 76.5898},
    {"address": "проспект Победы 10, Нижневартовск", "lat": 60.9351, "lng": 76.5621},
    {"address": "ул. Омская 12, Нижневартовск", "lat": 60.9362, "lng": 76.5489},
    {"address": "ул. Интернациональная 29, Нижневартовск", "lat": 60.9548, "lng": 76.5790},
    {"address": "ул. 60 лет Октября 4, Нижневартовск", "lat": 60.9298, "lng": 76.5540},
    {"address": "ул. Ханты-Мансийская 21, Нижневартовск", "lat": 60.9465, "lng": 76.6210},
    {"address": "ул. Мусы Джалиля 5, Нижневартовск", "lat": 60.9310, "lng": 76.5670},
    {"address": "ул. Маршала Жукова 3, Нижневартовск", "lat": 60.9405, "lng": 76.5615},
]

ITEMS = [
    {
        "title": "Пропала собака породы Хаски",
        "description": "25 июня в районе 10 микрорайона убежала собака, кобель, отзывается на кличку Буран. Был в синем ошейнике. Просьба вернуть за вознаграждение!",
        "category": "Потеряно животное",
        "source": "vk:lost_pets_nv",
        "telegram_channel": "Потеряшки Нижневартовск"
    },
    {
        "title": "Найден серый котенок",
        "description": "В подъезде дома по улице Ленина найден маленький котенок серого окраса, на вид около 2 месяцев. Очень ласковый, ищет старых или новых хозяев.",
        "category": "Найдено животное",
        "source": "tg:@podslushano_dogs_nv",
        "telegram_channel": "Животные НВ"
    },
    {
        "title": "Убежал рыжий кот Рыжик",
        "description": "Выпал из окна 2 этажа на улице Дружбы Народов. Рыжий, пушистый, глаза зеленые. Если кто видел или приютил, пожалуйста, позвоните!",
        "category": "Потеряно животное",
        "source": "vk:typical.nizhnevartovsk",
        "telegram_channel": "Типичный Нижневартовск"
    },
    {
        "title": "Найдена собака (похожа на лабрадора)",
        "description": "Бегает в ошейнике около ТЦ Югра, заглядывает в проезжающие машины, явно потерялась. К людям идет охотно, спокойная.",
        "category": "Найдено животное",
        "source": "tg:@accidents_in_nizhnevartovsk",
        "telegram_channel": "ЧП Нижневартовск"
    },
    {
        "title": "Пропал попугай корелла",
        "description": "Улетел через балкон на улице Чапаева. Зовут Кеша, разговаривает. Нашедшему гарантируется хорошее вознаграждение.",
        "category": "Потеряно животное",
        "source": "vk:lost_nv",
        "telegram_channel": "Бюро находок"
    },
    {
        "title": "Найдены ключи от автомобиля KIA",
        "description": "Найдены ключи с брелоком сигнализации Starline на детской площадке во дворе проспекта Победы. Верну владельцу при предъявлении документов на авто.",
        "category": "Найдена вещь",
        "source": "vk:bureau_nv",
        "telegram_channel": "Бюро находок НВ"
    },
    {
        "title": "Утерян черный кожаный рюкзак",
        "description": "26 июня в рюкзаке находились документы на имя Иванова А.В., студенческий билет и наушники. Просьба вернуть за вознаграждение хотя бы документы!",
        "category": "Потеряна вещь",
        "source": "tg:@justnow_nv",
        "telegram_channel": "Бюро находок"
    },
    {
        "title": "Найдена детская коляска",
        "description": "В районе набережной найдена прогулочная детская коляска бирюзового цвета. Забыли на лавочке. Писать в ЛС.",
        "category": "Найдена вещь",
        "source": "vk:typical.nizhnevartovsk",
        "telegram_channel": "Типичный Нижневартовск"
    },
    {
        "title": "Потерян мобильный телефон iPhone 12",
        "description": "Потерян телефон в черном чехле в районе парка Победы. Нашедшего очень прошу вернуть, внутри важные семейные фотографии.",
        "category": "Потеряна вещь",
        "source": "vk:4p86r",
        "telegram_channel": "ЧП Нижневартовск"
    },
    {
        "title": "Найден школьный рюкзак с учебниками",
        "description": "Оставлен на остановке общественного транспорта по улице Омская. Внутри тетради на имя ученика 5 класса.",
        "category": "Найдена вещь",
        "source": "tg:@chp_nv_86",
        "telegram_channel": "Наш Нижневартовск"
    },
    {
        "title": "Пропала связка ключей",
        "description": "Связка из трех ключей с зеленым пластиковым брелоком потеряна по дороге от школы до ТЦ. Просьба вернуть.",
        "category": "Потеряна вещь",
        "source": "vk:lost_nv",
        "telegram_channel": "Бюро находок"
    },
    {
        "title": "Найдена банковская карта Сбербанк",
        "description": "Найдена карта на имя Evgenii S. на улице Интернациональная. Заблокирована, верну владельцу.",
        "category": "Найдена вещь",
        "source": "vk:bureau_nv",
        "telegram_channel": "Бюро находок НВ"
    }
]

def seed():
    db = SessionLocal()
    try:
        # Удаляем старые записи
        deleted = db.query(Report).filter(Report.category.in_([
            'Потеряно животное', 'Найдено животное', 'Потеряна вещь', 'Найдена вещь'
        ])).delete(synchronize_session=False)
        print(f"Удалено старых записей бюро находок: {deleted}")

        inserted = 0
        now = datetime.utcnow()
        for item in ITEMS:
            loc = random.choice(LOCATIONS)
            days_ago = random.randint(0, 6)
            hours_ago = random.randint(1, 23)
            created_at = now - timedelta(days=days_ago, hours=hours_ago)
            
            report = Report(
                title=item["title"],
                description=item["description"],
                lat=loc["lat"],
                lng=loc["lng"],
                address=loc["address"],
                category=item["category"],
                status="open",
                source=item["source"],
                telegram_channel=item["telegram_channel"],
                supporters=0,
                supporters_notified=0,
                likes_count=0,
                dislikes_count=0,
                created_at=created_at,
                updated_at=created_at
            )
            db.add(report)
            inserted += 1
        
        db.commit()
        print(f"Успешно импортировано {inserted} записей бюро находок.")
    except Exception as e:
        db.rollback()
        print(f"Ошибка при импорте: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed()
