#!/usr/bin/env python3
"""
Полная авторизация в Telegram с паролем
"""

import asyncio
import os
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
PASSWORD = 'j498drz5ke'

async def main():
    print(f"🔐 Авторизация в Telegram...")
    print(f"📱 Телефон: {PHONE}")
    
    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    
    try:
        await client.start(
            phone=PHONE,
            password=PASSWORD
        )
        
        me = await client.get_me()
        print(f"✅ Авторизован как: {me.first_name} (@{me.username})")
        print(f"   ID: {me.id}")
        print(f"   Телефон: {me.phone}")
        
        await client.disconnect()
        print("✅ Сессия сохранена в monitoring_session.session")
        print("✅ Теперь можно запускать мониторинг!")
        
    except Exception as e:
        print(f"❌ Ошибка авторизации: {e}")
        import traceback
        traceback.print_exc()
        await client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
