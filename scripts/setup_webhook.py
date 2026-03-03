#!/usr/bin/env python3
"""
Установить Telegram webhook на публичный URL.
Использование:
    python scripts/setup_webhook.py https://your-domain.com
"""
import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv()

from aiogram import Bot


async def main(base_url: str):
    token = os.getenv("TG_BOT_TOKEN")
    if not token:
        print("Error: TG_BOT_TOKEN not set")
        sys.exit(1)
    
    bot = Bot(token=token)
    webhook_url = f"{base_url.rstrip('/')}/webhook/telegram"
    
    try:
        # Удалить старый webhook
        await bot.delete_webhook(drop_pending_updates=True)
        print("Old webhook deleted")
        
        # Установить новый
        await bot.set_webhook(webhook_url, drop_pending_updates=True)
        print(f"Webhook set: {webhook_url}")
        
        # Проверить
        info = await bot.get_webhook_info()
        print(f"Webhook info: url={info.url}, pending={info.pending_update_count}")
        
    finally:
        await bot.session.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/setup_webhook.py <base_url>")
        print("Example: python scripts/setup_webhook.py https://pulsenv-bot.onrender.com")
        sys.exit(1)
    
    asyncio.run(main(sys.argv[1]))
