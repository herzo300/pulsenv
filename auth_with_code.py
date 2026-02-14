#!/usr/bin/env python3
"""
Авторизация в Telegram с кодом 10287
"""

import asyncio
import os
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')
CODE = '89283'
PASSWORD = 'j498drz5ke'

async def main():
    print(f"🔐 Авторизация в Telegram...")
    print(f"📱 Телефон: {PHONE}")
    print(f"🔢 Код: {CODE}")
    print(f"🔒 Пароль: {'*' * len(PASSWORD)}")
    
    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    
    try:
        await client.connect()
        
        if not await client.is_user_authorized():
            await client.send_code_request(PHONE)
            try:
                await client.sign_in(PHONE, CODE)
            except Exception as e:
                if 'password' in str(e).lower():
                    print("🔒 Требуется пароль 2FA...")
                    await client.sign_in(password=PASSWORD)
                else:
                    raise e
        
        me = await client.get_me()
        print(f"✅ Авторизован как: {me.first_name} (@{me.username})")
        print(f"   ID: {me.id}")
        
        await client.disconnect()
        print("✅ Сессия сохранена в monitoring_session.session")
        
    except Exception as e:
        print(f"❌ Ошибка авторизации: {e}")
        await client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
