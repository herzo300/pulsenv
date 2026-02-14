#!/usr/bin/env python3
"""
Авторизация в Telegram с кодом
"""

import asyncio
import os
from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv('TG_API_ID', 0))
API_HASH = os.getenv('TG_API_HASH', '')
PHONE = os.getenv('TG_PHONE', '')

async def main():
    client = TelegramClient('monitoring_session', API_ID, API_HASH)
    
    await client.start(
        phone=PHONE,
        code_callback=lambda: input('Введите код: ')
    )
    
    me = await client.get_me()
    print(f"✅ Авторизован как: {me.first_name} (@{me.username})")
    
    await client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
