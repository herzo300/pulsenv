#!/usr/bin/env python3
"""
Обработка жалобы: AI анализ → БД → публикация в @monitornv
"""
import asyncio
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from telethon import TelegramClient
from backend.database import SessionLocal
from backend.models import Report, User
from services.zai_service import analyze_complaint, CATEGORIES
from services.geo_service import get_coordinates

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
TARGET_CHANNEL = '@monitornv'

EMOJI = {
    "ЖКХ": "🏘️", "Дороги": "🛣️", "Благоустройство": "🌳", "Транспорт": "🚌",
    "Экология": "♻️", "Животные": "🐶", "Торговля": "🛒", "Безопасность": "🚨",
    "Снег/Наледь": "❄️", "Освещение": "💡", "Медицина": "🏥", "Образование": "🏫",
    "Связь": "📶", "Строительство": "🚧", "Парковки": "🅿️", "Прочее": "❔",
    "ЧП": "🚨", "Газоснабжение": "🔥", "Водоснабжение и канализация": "💧",
    "Отопление": "🌡️", "Бытовой мусор": "🗑️", "Лифты и подъезды": "🏢",
    "Парки и скверы": "🌲", "Спортивные площадки": "⚽", "Детские площадки": "🎠",
}

TAG = {
    "ЖКХ": "жкх", "Дороги": "дороги", "Благоустройство": "благоустройство",
    "Транспорт": "транспорт", "Экология": "экология", "Снег/Наледь": "снег",
    "Освещение": "освещение", "Безопасность": "безопасность", "Прочее": "прочее",
    "ЧП": "ЧП", "Медицина": "медицина",
}

# Тестовая жалоба
COMPLAINT_TEXT = """На улице Мира 62 уже третий день не работает уличное освещение. 
Весь двор в темноте, дети боятся выходить вечером. Фонари не горят на протяжении 
всего квартала от дома 60 до 66. Просим срочно починить!"""


async def process():
    print("=" * 60)
    print("🔄 Обработка жалобы через AI")
    print("=" * 60)
    print(f"\n📝 Текст жалобы:\n{COMPLAINT_TEXT}\n")

    # 1. AI анализ
    print("🤖 Анализ через AI...")
    result = await analyze_complaint(COMPLAINT_TEXT)
    category = result.get("category", "Прочее")
    address = result.get("address")
    summary = result.get("summary", COMPLAINT_TEXT[:100])
    error = result.get("error")

    if error:
        print(f"⚠️  AI fallback: {error}")
    
    print(f"   Категория: {category}")
    print(f"   Адрес: {address}")
    print(f"   Резюме: {summary}")

    # 2. Геокодинг
    lat, lon = None, None
    if address:
        print(f"\n📍 Геокодинг: {address}")
        coords = await get_coordinates(address)
        if coords:
            lat, lon = coords
            print(f"   Координаты: {lat:.4f}, {lon:.4f}")
        else:
            print("   Координаты не найдены")

    # 3. Сохранение в БД
    print("\n💾 Сохранение в базу данных...")
    db = SessionLocal()
    try:
        report = Report(
            title=summary[:200],
            description=COMPLAINT_TEXT,
            lat=lat,
            lng=lon,
            address=address,
            category=category,
            status="open",
            source="test_complaint",
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        print(f"   ✅ Жалоба #{report.id} сохранена")
    finally:
        db.close()

    # 4. Публикация в канал
    emoji = EMOJI.get(category, "❔")
    tag = TAG.get(category, "прочее")

    msg_lines = [
        f"{emoji} [{category}] #{report.id}",
        f"",
        f"📝 {summary}",
    ]
    if address:
        msg_lines.append(f"📍 {address}")
    if lat and lon:
        msg_lines.append(f"🗺️ {lat:.4f}, {lon:.4f}")
    msg_lines.append(f"")
    msg_lines.append(f"🕐 {datetime.now().strftime('%d.%m.%Y %H:%M')}")
    msg_lines.append(f"📢 Источник: тестовая жалоба")
    msg_lines.append(f"")
    msg_lines.append(f"#{tag} #ПульсГорода #Нижневартовск")

    publish_text = "\n".join(msg_lines)
    print(f"\n📤 Публикация в {TARGET_CHANNEL}...")
    print(f"---\n{publish_text}\n---")

    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    try:
        await client.start(phone=PHONE)
        message = await client.send_message(TARGET_CHANNEL, publish_text)
        print(f"✅ Опубликовано! ID: {message.id}")
        print(f"🔗 https://t.me/monitornv/{message.id}")
    except Exception as e:
        print(f"❌ Ошибка публикации: {e}")
    finally:
        await client.disconnect()

    print(f"\n{'=' * 60}")
    print(f"✅ Готово! Жалоба #{report.id} обработана и опубликована")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    asyncio.run(process())
