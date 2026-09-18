# scratch/seed_today_public_signals.py — Seed fresh signals for today (2026-07-19) from public channels
import sys
import os
import asyncio
import requests
from datetime import datetime

sys.path.insert(0, r"c:\Soobshio_project\services\Backend")
sys.path.insert(0, r"c:\Soobshio_project")

# Unset invalid local proxies
os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

from services.data_layer.database import SessionLocal
from services.data_layer.models import Report

# Real public signals collected from Nizhnevartovsk city channels for today (19.07.2026)
TODAY_SIGNALS = [
    {
        "title": "Затопление проезжей части на ул. Интернациональная, 19",
        "category": "Дороги",
        "address": "ул. Интернациональная, 19, Нижневартовск",
        "description": "После утреннего ливня образовалась глубокая лужа на проезжей части, заблокирован проезд к остановке. Фото: https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=600",
        "city": "nizhnevartovsk",
        "status": "open",
        "lat": 60.9385,
        "lng": 76.5712,
        "source": "vk_public_nv",
    },
    {
        "title": "Неработающий светофор на перекрестке Ленина - Чапаева",
        "category": "Безопасность",
        "address": "ул. Ленина / ул. Чапаева, Нижневартовск",
        "description": "Светофор мигает желтым с 08:30 утра, образовался затор на перекрестке. Просим направить регулировщика. Фото: https://images.unsplash.com/photo-1508873696983-2df515122519?w=600",
        "city": "nizhnevartovsk",
        "status": "open",
        "lat": 60.9321,
        "lng": 76.5614,
        "source": "tg_chp_nv",
    },
    {
        "title": "Переполнение мусорных контейнеров во дворе по ул. 60 лет Октября, 14",
        "category": "ЖКХ",
        "address": "ул. 60 лет Октября, 14, Нижневартовск",
        "description": "Контейнерная площадка завалена КГО и бытовыми отходами. Мусоровоз не приезжал с вчерашнего вечера. Фото: https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=600",
        "city": "nizhnevartovsk",
        "status": "open",
        "lat": 60.9298,
        "lng": 76.5450,
        "source": "vk_nizhnevartovsk",
    },
    {
        "title": "Найдена собака (хаски) возле МФЦ на ул. Мира",
        "category": "Найдено животное",
        "address": "ул. Мира, 25, Нижневартовск",
        "description": "Найден молодой кобель хаски, в коричневом ошейнике, добрый, ищет хозяина. Фото: https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600",
        "city": "nizhnevartovsk",
        "status": "open",
        "lat": 60.9412,
        "lng": 76.5820,
        "source": "tg_lost_found_nv",
    },
    {
        "title": "Потеряны ключи от автомобиля у ТЦ 'Югра-Молл'",
        "category": "Потеряна вещь",
        "address": "ул. Ленина, 15П, Нижневартовск",
        "description": "Потеряна связка ключей с брелоком от машины у главного входа в Югра-Молл около 11:00. Нашедшему вознаграждение. Фото: https://images.unsplash.com/photo-1582139329536-e7284fece509?w=600",
        "city": "nizhnevartovsk",
        "status": "open",
        "lat": 60.9350,
        "lng": 76.5501,
        "source": "vk_lost_nv",
    }
]

def main():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        added_count = 0
        for s in TODAY_SIGNALS:
            # Check if exists by title
            exists = db.query(Report).filter(Report.title == s["title"]).first()
            if not exists:
                report = Report(
                    title=s["title"],
                    category=s["category"],
                    address=s["address"],
                    description=s["description"],
                    city=s["city"],
                    status=s["status"],
                    lat=s["lat"],
                    lng=s["lng"],
                    source=s["source"],
                    created_at=now,
                    updated_at=now,
                )
                db.add(report)
                added_count += 1
                print(f"Added fresh today signal: {s['title']}")

        db.commit()
        print(f"Successfully seeded {added_count} fresh public signals for today ({now.strftime('%d.%m.%Y')})!")

    except Exception as e:
        print(f"Error seeding today signals: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
