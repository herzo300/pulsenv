#!/usr/bin/env python3
"""
Простой тест бота - отправка команд
"""

import asyncio
import os
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
BOT_USERNAME = '@pulsenvbot'

async def test_bot():
    """Тестирует бота"""
    client = TelegramClient('simple_test_session', API_ID, API_HASH)
    
    try:
        await client.start(phone=PHONE)
        print("✅ Подключено к Telegram")
        
        me = await client.get_me()
        print(f"👤 Авторизован как: {me.first_name}")
        
        # Получаем бота
        bot = await client.get_entity(BOT_USERNAME)
        print(f"🤖 Найден бот: {bot.username}\n")
        
        # Тест команды /map
        print("🗺️ Тестирование команды /map...")
        await client.send_message(bot, '/map')
        print("✅ Команда /map отправлена")
        
        await asyncio.sleep(3)
        
        # Получаем последние сообщения от бота
        print("\n📨 Получение ответов от бота...")
        messages = await client.get_messages(bot, limit=10)
        
        print(f"\n📬 Получено {len(messages)} сообщений:")
        for i, msg in enumerate(messages, 1):
            if msg.text:
                print(f"\n{i}. {msg.text[:200]}...")
            elif msg.media:
                print(f"\n{i}. [Медиа: {type(msg.media).__name__}]")
        
        print("\n✅ Тест завершен!")
        print("\n💡 Проверьте Telegram:")
        print(f"   Откройте чат с {BOT_USERNAME}")
        print("   Проверьте ответ на команду /map")
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        import traceback
        traceback.print_exc()
    finally:
        await client.disconnect()

if __name__ == "__main__":
    asyncio.run(test_bot())
