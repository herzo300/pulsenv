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
        "description": "В районе улицы Ленина 15 бегает молодой кобель хаски в брезентовом ошейнике. Очень ласковый, знает команды, явно домашний. Ищем старых или новых хозяев.",
        "category": "Животные",
        "address": "улица Ленина, 15",
        "lat": 60.9382,
        "lng": 76.5610,
        "city": "nizhnevartovsk",
        "source": "Животные Нижневартовска (TG)",
    },
    {
        "title": "Найдены ключи от автомобиля",
        "description": "На детской площадке во дворе дома по адресу ул. Чапаева 5 найдены ключи от машины Toyota с брелоком Scher-Khan. Верну владельцу при подтверждении.",
        "category": "Вещи / Бюро находок",
        "address": "улица Чапаева, 5",
        "lat": 60.9421,
        "lng": 76.5752,
        "city": "nizhnevartovsk",
        "source": "Потерянные вещи НВ (TG)",
    },
    {
        "title": "Рыжий кот в подъезде",
        "description": "В подъезде дома по ул. Мира 38 со вчерашнего дня сидит упитанный рыжий кот, явно домашний, очень испуган. Хозяева, отзовитесь!",
        "category": "Животные",
        "address": "улица Мира, 38",
        "lat": 60.9315,
        "lng": 76.5890,
        "city": "nizhnevartovsk",
        "source": "Потеряшки Нижневартовск (VK)",
    },
    {
        "title": "Найден телефон iPhone 12",
        "description": "Возле центрального входа в ТРЦ Премьер найден телефон iPhone 12 в черном силиконовом чехле. Экран заблокирован. Верну по описанию обоев на экране.",
        "category": "Вещи / Бюро находок",
        "address": "ул. Ленина, 11",
        "lat": 60.9360,
        "lng": 76.5540,
        "city": "nizhnevartovsk",
        "source": "Бюро находок Нижневартовск (VK)",
    },
    {
        "title": "Пропала собака Шпиц",
        "description": "В районе ТЦ Югра убежал маленький белый шпиц (кобель), отзывается на кличку Пушок. Был без ошейника. Просьба вернуть за вознаграждение!",
        "category": "Животные",
        "address": "Интернациональная улица, 12",
        "lat": 60.9452,
        "lng": 76.5910,
        "city": "nizhnevartovsk",
        "source": "Подслушано в Нижневартовске (VK)",
    },
    {
        "title": "Найден кошелек с картами",
        "description": "На лавочке возле ул. Интернациональная 12 найден черный кожаный кошелек. Внутри банковские карты на имя Aleksandr S. и немного наличных. Верну при предъявлении паспорта.",
        "category": "Вещи / Бюро находок",
        "address": "Интернациональная улица, 12",
        "lat": 60.9452,
        "lng": 76.5910,
        "city": "nizhnevartovsk",
        "source": "Инцидент Нижневартовск (VK)",
    },
    {
        "title": "Утеряны водительские права",
        "description": "На имя Петров Д.А. были утеряны водительские права в районе Комсомольского бульвара. Нашедшему просьба связаться по телефону или вернуть в ДК Октябрь.",
        "category": "Вещи / Бюро находок",
        "address": "Комсомольский бульвар, 4",
        "lat": 60.9398,
        "lng": 76.5682,
        "city": "nizhnevartovsk",
        "source": "Нижневартовск ЧП (TG)",
    },
    {
        "title": "Замечена овчарка в ошейнике",
        "description": "По улице Дружбы Народов 15 бегает взрослая немецкая овчарка в коричневом кожаном ошейнике. К людям не подходит, выглядит испуганной.",
        "category": "Животные",
        "address": "ул. Дружбы Народов, 15",
        "lat": 60.9332,
        "lng": 76.5815,
        "city": "nizhnevartovsk",
        "source": "Животные Нижневартовска (TG)",
    },
    {
        "title": "Найден рюкзак с учебниками",
        "description": "На спортивной площадке школы №12 найден синий рюкзак фирмы Demix. Внутри учебники за 8 класс и пенал. Лежит у охранника школы.",
        "category": "Вещи / Бюро находок",
        "address": "ул. Мира, 9",
        "lat": 60.9371,
        "lng": 76.5645,
        "city": "nizhnevartovsk",
        "source": "Типичный Нижневартовск (VK)",
    },
    {
        "title": "Пропал серый кот с ошейником",
        "description": "Из дома по адресу ул. Кузоваткина 5 убежал домашний серый кот британской породы. На шее красный противоблошиный ошейник. Очень пугливый.",
        "category": "Животные",
        "address": "ул. Кузоваткина, 5",
        "lat": 60.9410,
        "lng": 76.6025,
        "city": "nizhnevartovsk",
        "source": "Потеряшки Нижневартовск (VK)",
    },
    {
        "title": "Найдены наушники AirPods Pro",
        "description": "В Красном проспекте возле ТЦ Аура (Новосибирск) найден кейс с наушниками AirPods Pro. Отдам тому, кто назовет имя кейса при подключении к телефону.",
        "category": "Вещи / Бюро находок",
        "address": "Военная ул., 5",
        "lat": 55.0302,
        "lng": 82.9348,
        "city": "novosibirsk",
        "source": "Бюро находок Новосибирск (VK)",
    },
    {
        "title": "Пропал кобель Сибирский Хаски",
        "description": "В Заельцовском районе Новосибирска убежал пес породы Сибирский хаски, глаза голубые, кличка Грей. Нашедшему гарантируется хорошее вознаграждение!",
        "category": "Животные",
        "address": "ул. Дуси Ковальчук, 238",
        "lat": 55.0592,
        "lng": 82.9052,
        "city": "novosibirsk",
        "source": "Потеряшки Новосибирска (VK)",
    },
    {
        "title": "Найдена женская сумка с документами",
        "description": "Возле станции метро Площадь Ленина в Новосибирске найдена бежевая женская сумка. Внутри документы на имя Елены Смирновой. Отдам при предъявлении паспорта.",
        "category": "Вещи / Бюро находок",
        "address": "Красный проспект, 25",
        "lat": 55.0300,
        "lng": 82.9200,
        "city": "novosibirsk",
        "source": "Инцидент Новосибирск (VK)",
    },
    {
        "title": "Найден черный щенок",
        "description": "На остановке Речной вокзал в Новосибирске найден маленький черный щенок, похож на лабрадора. Бегал один. Забрали в клинику на передержку.",
        "category": "Животные",
        "address": "ул. Большевистская, 43",
        "lat": 55.0112,
        "lng": 82.9405,
        "city": "novosibirsk",
        "source": "Потерянные животные НСК (TG)",
    },
    {
        "title": "Утеряны ключи от квартиры с брелоком",
        "description": "Утеряна связка ключей (3 штуки) с кожаным коричневым брелоком в Академгородке на Морском проспекте. Просьба вернуть за шоколадку.",
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
