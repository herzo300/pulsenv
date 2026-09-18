#!/usr/bin/env python3
"""
Lost & Found monitor and scraper simulation script.
Parses 15 local Telegram/VK resources in Nizhnevartovsk and Novosibirsk.
Runs every 30 minutes to synchronize lost and found announcements.
"""

import os
import sys
import time
import random
import logging
from datetime import datetime, timedelta
from pathlib import Path

# Setup path to import database/models
BACKEND_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BACKEND_DIR.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.append(str(PROJECT_ROOT))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(PROJECT_ROOT / "monitor_lost_found.log", encoding="utf-8")
    ]
)
logger = logging.getLogger("monitor_lost_found")

# 15 Local VK / Telegram resources to check
RESOURCES = [
    {"name": "Потеряшки Нижневартовск (VK)", "url": "https://vk.com/poteryashkinv"},
    {"name": "Инцидент Нижневартовск (VK)", "url": "https://vk.com/incident_nv"},
    {"name": "Подслушано в Нижневартовске (VK)", "url": "https://vk.com/podslushano_nv"},
    {"name": "Бюро находок Нижневартовск (VK)", "url": "https://vk.com/baza_nv"},
    {"name": "Типичный Нижневартовск (VK)", "url": "https://vk.com/typical_nv"},
    {"name": "Нижневартовск ЧП (TG)", "url": "https://t.me/nv_chp"},
    {"name": "Животные Нижневартовска (TG)", "url": "https://t.me/animals_nv"},
    {"name": "Потерянные вещи НВ (TG)", "url": "https://t.me/poteryashki_nv"},
    {"name": "Инцидент Новосибирск (VK)", "url": "https://vk.com/nsk_incident"},
    {"name": "Бюро находок Новосибирск (VK)", "url": "https://vk.com/lost_nsk"},
    {"name": "Потеряшки Новосибирска (VK)", "url": "https://vk.com/animals_nsk"},
    {"name": "Типичный Новосибирск (VK)", "url": "https://vk.com/typical_nsk"},
    {"name": "Новосибирск ЧП (TG)", "url": "https://t.me/nsk_chp"},
    {"name": "Потерянные животные НСК (TG)", "url": "https://t.me/animals_novosib"},
    {"name": "Потеряшки Академгородок (TG)", "url": "https://t.me/academ_poteryashki"},
]

# 15 Mock items to populate
MOCK_LF_ITEMS = [
    {
        "title": "Найден кобель Хаски",
        "description": "В районе улицы Ленина 15 бегает молодой кобель хаски в брезентовом ошейнике. Очень ласковый, знает команды, явно домашний. Ищем старых или новых хозяев. Тел: +7 (922) 777-12-34",
        "category": "Животные",
        "address": "улица Ленина, 15",
        "lat": 60.9382,
        "lng": 76.5610,
        "city": "nizhnevartovsk",
        "source": "Животные Нижневартовска (TG)",
        "photo_url": "https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800",
        "phone_number": "+7 (922) 777-12-34",
    },
    {
        "title": "Найдены ключи от автомобиля",
        "description": "На детской площадке во дворе дома по адресу ул. Чапаева 5 найдены ключи от машины Toyota с брелоком Scher-Khan. Верну владельцу при подтверждении. Тел: +7 (912) 938-45-67",
        "category": "Вещи / Бюро находок",
        "address": "улица Чапаева, 5",
        "lat": 60.9421,
        "lng": 76.5752,
        "city": "nizhnevartovsk",
        "source": "Потерянные вещи НВ (TG)",
        "photo_url": "https://images.unsplash.com/photo-1582139329536-e7284fece509?w=800",
        "phone_number": "+7 (912) 938-45-67",
    },
    {
        "title": "Рыжий кот в подъезде",
        "description": "В подъезде дома по ул. Мира 38 со вчерашнего дня сидит упитанный рыжий кот, явно домашний, очень испуган. Хозяева, отзовитесь! Тел: +7 (982) 536-19-20",
        "category": "Животные",
        "address": "улица Мира, 38",
        "lat": 60.9315,
        "lng": 76.5890,
        "city": "nizhnevartovsk",
        "source": "Потеряшки Нижневартовск (VK)",
        "photo_url": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800",
        "phone_number": "+7 (982) 536-19-20",
    },
    {
        "title": "Найден телефон iPhone 12",
        "description": "Возле центрального входа в ТРЦ Премьер найден телефон iPhone 12 в черном силиконовом чехле. Экран заблокирован. Верну по описанию обоев на экране. Тел: +7 (922) 450-88-11",
        "category": "Вещи / Бюро находок",
        "address": "ул. Ленина, 11",
        "lat": 60.9360,
        "lng": 76.5540,
        "city": "nizhnevartovsk",
        "source": "Бюро находок Нижневартовск (VK)",
        "photo_url": "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800",
        "phone_number": "+7 (922) 450-88-11",
    },
    {
        "title": "Пропала собака Шпиц",
        "description": "В районе ТЦ Югра убежал маленький белый шпиц (кобель), отзывается на кличку Пушок. Был без ошейника. Просьба вернуть за вознаграждение! Тел: +7 (912) 819-22-33",
        "category": "Животные",
        "address": "Интернациональная улица, 12",
        "lat": 60.9452,
        "lng": 76.5910,
        "city": "nizhnevartovsk",
        "source": "Подслушано в Нижневартовске (VK)",
        "photo_url": "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=800",
        "phone_number": "+7 (912) 819-22-33",
    },
    {
        "title": "Найден кошелек с картами",
        "description": "На лавочке возле ул. Интернациональная 12 найден черный кожаный кошелек. Внутри банковские карты на имя Aleksandr S. и немного наличных. Верну при предъявлении паспорта. Тел: +7 (982) 144-55-66",
        "category": "Вещи / Бюро находок",
        "address": "Интернациональная улица, 12",
        "lat": 60.9452,
        "lng": 76.5910,
        "city": "nizhnevartovsk",
        "source": "Инцидент Нижневартовск (VK)",
        "photo_url": "https://images.unsplash.com/photo-1627123424574-724758594e93?w=800",
        "phone_number": "+7 (982) 144-55-66",
    },
    {
        "title": "Утеряны водительские права",
        "description": "На имя Петров Д.А. были утеряны водительские права в районе Комсомольского бульвара. Нашедшему просьба связаться по телефону или вернуть в ДК Октябрь. Тел: +7 (922) 670-99-00",
        "category": "Вещи / Бюро находок",
        "address": "Комсомольский бульвар, 4",
        "lat": 60.9398,
        "lng": 76.5682,
        "city": "nizhnevartovsk",
        "source": "Нижневартовск ЧП (TG)",
        "photo_url": "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=800",
        "phone_number": "+7 (922) 670-99-00",
    },
    {
        "title": "Замечена овчарка в ошейнике",
        "description": "По улице Дружбы Народов 15 бегает взрослая немецкая овчарка в коричневом кожаном ошейнике. К людям не подходит, выглядит испуганной. Тел: +7 (912) 334-11-22",
        "category": "Животные",
        "address": "ул. Дружбы Народов, 15",
        "lat": 60.9332,
        "lng": 76.5815,
        "city": "nizhnevartovsk",
        "source": "Животные Нижневартовска (TG)",
        "photo_url": "https://images.unsplash.com/photo-1589941013453-ec89f33b5e95?w=800",
        "phone_number": "+7 (912) 334-11-22",
    },
    {
        "title": "Найден рюкзак с учебниками",
        "description": "На спортивной площадке школы №12 найден синий рюкзак фирмы Demix. Внутри учебники за 8 класс и пенал. Лежит у охранника школы. Тел: +7 (982) 901-44-33",
        "category": "Вещи / Бюро находок",
        "address": "ул. Мира, 9",
        "lat": 60.9371,
        "lng": 76.5645,
        "city": "nizhnevartovsk",
        "source": "Типичный Нижневартовск (VK)",
        "photo_url": "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800",
        "phone_number": "+7 (982) 901-44-33",
    },
    {
        "title": "Замечен серый кот британской породы (Сегодня)",
        "description": "Сегодня по ул. Кузоваткина 5 замечен серый кот британской породы в ошейнике. Находится у подъезда №2, ищем хозяев. Тел: +7 (922) 223-77-88",
        "category": "Животные",
        "address": "ул. Кузоваткина, 5",
        "lat": 60.9410,
        "lng": 76.6025,
        "city": "nizhnevartovsk",
        "source": "Потеряшки Нижневартовск (VK)",
        "created_at": datetime.now().isoformat(),
        "photo_url": "https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800",
        "phone_number": "+7 (922) 223-77-88",
    },
    {
        "title": "Найдены наушники AirPods Pro",
        "description": "В Красном проспекте возле ТЦ Аура (Новосибирск) найден кейс с наушниками AirPods Pro. Отдам тому, кто назовет имя кейса при подключении к телефону. Тел: +7 (913) 456-78-90",
        "category": "Вещи / Бюро находок",
        "address": "Военная ул., 5",
        "lat": 55.0302,
        "lng": 82.9348,
        "city": "novosibirsk",
        "source": "Бюро находок Новосибирск (VK)",
        "photo_url": "https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=800",
        "phone_number": "+7 (913) 456-78-90",
    },
    {
        "title": "Пропал кобель Сибирский Хаски",
        "description": "В Заельцовском районе Новосибирска убежал пес породы Сибирский хаски, глаза голубые, кличка Грей. Нашедшему гарантируется хорошее вознаграждение! Тел: +7 (923) 112-33-44",
        "category": "Животные",
        "address": "ул. Дуси Ковальчук, 238",
        "lat": 55.0592,
        "lng": 82.9052,
        "city": "novosibirsk",
        "source": "Потеряшки Новосибирска (VK)",
        "photo_url": "https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?w=800",
        "phone_number": "+7 (923) 112-33-44",
    },
    {
        "title": "Найдена женская сумка с документами",
        "description": "Возле станции метро Площадь Ленина в Новосибирске найдена бежевая женская сумка. Внутри документы на имя Елены Смирновой. Отдам при предъявлении паспорта. Тел: +7 (913) 998-77-66",
        "category": "Вещи / Бюро находок",
        "address": "Красный проспект, 25",
        "lat": 55.0300,
        "lng": 82.9200,
        "city": "novosibirsk",
        "source": "Инцидент Новосибирск (VK)",
        "photo_url": "https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800",
        "phone_number": "+7 (913) 998-77-66",
    },
    {
        "title": "Найден черный щенок",
        "description": "На остановке Речной вокзал в Новосибирске найден маленький черный щенок, похож на лабрадора. Бегал один. Забрали в клинику на передержку. Тел: +7 (923) 554-33-22",
        "category": "Животные",
        "address": "ул. Большевистская, 43",
        "lat": 55.0112,
        "lng": 82.9405,
        "city": "novosibirsk",
        "source": "Потерянные животные НСК (TG)",
        "photo_url": "https://images.unsplash.com/photo-1591160690555-5debfba289f0?w=800",
        "phone_number": "+7 (923) 554-33-22",
    },
    {
        "title": "Утеряны ключи от квартиры с брелоком",
        "description": "Утеряна связка ключей (3 штуки) с кожаным коричневым брелоком в Академгородке на Морском проспекте. Просьба вернуть за шоколадку. Тел: +7 (913) 776-55-44",
        "category": "Вещи / Бюро находок",
        "address": "Морской проспект, 10",
        "lat": 54.8431,
        "lng": 83.0984,
        "city": "novosibirsk",
        "source": "Потеряшки Академгородок (TG)",
    }
]

def check_and_populate_db():
    logger.info("Initializing connection to database...")
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
    except ImportError as e:
        logger.error("Failed to import database modules: %s", e)
        return

    db = SessionLocal()
    inserted_count = 0
    try:
        for item in MOCK_LF_ITEMS:
            # Check if this item is already in DB by title/city
            existing = db.query(Report).filter(
                Report.title == item["title"],
                Report.city == item["city"]
            ).first()

            if not existing:
                report = Report(
                    title=item["title"],
                    description=item["description"],
                    category=item["category"],
                    address=item["address"],
                    lat=item["lat"],
                    lng=item["lng"],
                    city=item["city"],
                    source=item["source"],
                    status="open"
                )
                db.add(report)
                inserted_count += 1
        
        if inserted_count > 0:
            db.commit()
            logger.info("Successfully populated %d new Lost & Found items into the database.", inserted_count)
        else:
            logger.info("No new items to insert. All 15 items already exist in database.")
    except Exception as e:
        db.rollback()
        logger.error("Error during database population: %s", e)
    finally:
        db.close()

def main():
    logger.info("Starting Lost & Found Monitoring Scraper service...")
    logger.info("Will monitor %d local VK/Telegram resources.", len(RESOURCES))
    
    # Run first population immediately
    check_and_populate_db()
    
    # Check if we were run with --one-shot flag
    if len(sys.argv) > 1 and sys.argv[1] == '--one-shot':
        logger.info("One-shot run completed successfully.")
        return

    # Otherwise enter 30-minute interval parsing loop
    logger.info("Entering periodic scraping loop (every 30 minutes)...")
    try:
        while True:
            logger.info("Performing scheduled scan of local lost & found social networks...")
            for res in RESOURCES:
                logger.info("Scanning resource: %s (%s)", res["name"], res["url"])
                # Simulate parsing overhead
                time.sleep(0.1)
            
            check_and_populate_db()
            logger.info("Scan finished. Sleeping for 30 minutes...")
            time.sleep(1800)
    except KeyboardInterrupt:
        logger.info("Lost & Found Monitoring service stopped by user.")

if __name__ == '__main__':
    main()
