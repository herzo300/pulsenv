#!/usr/bin/env python3
"""
Публикация тестового сообщения в канал @monitornv
"""

import asyncio
import os
from datetime import datetime
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
TARGET_CHANNEL = '@monitornv'

async def publish_test():
    """Публикует тестовое сообщение"""
    client = TelegramClient('publish_session', API_ID, API_HASH)
    
    try:
        await client.start(phone=PHONE)
        print("✅ Подключено к Telegram")
        
        me = await client.get_me()
        print(f"👤 Авторизован как: {me.first_name}")
        
        # Проверяем канал
        try:
            channel = await client.get_entity(TARGET_CHANNEL)
            print(f"✅ Канал найден: {channel.title}")
        except Exception as e:
            print(f"❌ Ошибка доступа к каналу {TARGET_CHANNEL}: {e}")
            return
        
        # Формируем тестовое сообщение
        test_message = f"""🤖 AI Мониторинг | {datetime.now().strftime('%d.%m.%Y %H:%M')}

🛣️ Категория: Дороги
📍 Адрес: улица Ленина 15, Нижневартовск
📍 Координаты: 60.9388, 76.5778

📝 Описание:
Большая яма на дороге, опасно для автомобилей. Требуется срочный ремонт. Глубина около 30 см, ширина 1 метр.

📢 Источник: @nizhnevartovsk_chp
🔗 Оригинал: ТЕСТ

#monitornv #Дороги #AI #ТЕСТ"""
        
        # Публикуем
        print(f"\n📤 Публикация в {TARGET_CHANNEL}...")
        await client.send_message(TARGET_CHANNEL, test_message)
        print("✅ Сообщение опубликовано!")
        
        print(f"\n📱 Проверьте канал {TARGET_CHANNEL}")
        print("   Тестовое сообщение должно появиться в канале")
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        import traceback
        traceback.print_exc()
    finally:
        await client.disconnect()

if __name__ == "__main__":
    print("🚀 Публикация тестового сообщения в канал...\n")
    asyncio.run(publish_test())
