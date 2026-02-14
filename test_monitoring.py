#!/usr/bin/env python3
"""
Тестовый скрипт для проверки мониторинга
Отправляет тестовое сообщение в один из каналов для проверки AI анализа
"""

import asyncio
import os
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')

# Тестовое сообщение
TEST_MESSAGE = """
🧪 ТЕСТ СИСТЕМЫ МОНИТОРИНГА

На улице Ленина 15 большая яма на дороге. 
Опасно для автомобилей, требуется срочный ремонт.
Глубина около 30 см, ширина 1 метр.

#тест #дороги #нижневартовск
"""

async def send_test_message():
    """Отправляет тестовое сообщение"""
    client = TelegramClient('test_session', API_ID, API_HASH)
    
    try:
        await client.start(phone=PHONE)
        print("✅ Подключено к Telegram")
        
        me = await client.get_me()
        print(f"👤 Авторизован как: {me.first_name}")
        
        # Отправляем в канал @nizhnevartovsk_chp (если есть права)
        # Или в Saved Messages для теста
        target = 'me'  # Saved Messages
        
        await client.send_message(target, TEST_MESSAGE)
        print(f"✅ Тестовое сообщение отправлено в {target}")
        print("\n📝 Текст сообщения:")
        print(TEST_MESSAGE)
        print("\n⏳ Проверьте логи мониторинга через несколько секунд...")
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")
    finally:
        await client.disconnect()

if __name__ == "__main__":
    asyncio.run(send_test_message())
