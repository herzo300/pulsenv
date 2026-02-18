#!/usr/bin/env python3
"""
Запуск бота в режиме Webhook (без getUpdates — нет конфликта).
Требует: WEBHOOK_BASE_URL в .env (HTTPS, напр. https://your-domain.com)
         main.py (uvicorn) должен быть доступен по этому URL.
"""
import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
os.chdir(sys.path[0])

from dotenv import load_dotenv
load_dotenv()


async def main():
    from core.config import TG_BOT_TOKEN, WEBHOOK_BASE_URL
    from services.telegram_bot import bot, setup_menu

    if not WEBHOOK_BASE_URL:
        print("Ошибка: WEBHOOK_BASE_URL не задан в .env")
        print("Пример: WEBHOOK_BASE_URL=https://your-domain.com")
        sys.exit(1)

    url = f"{WEBHOOK_BASE_URL.rstrip('/')}/webhook/telegram"
    await setup_menu()
    await bot.set_webhook(url)
    print(f"Webhook установлен: {url}")
    print("Бот работает через webhook. Убедитесь, что main.py (uvicorn) запущен и доступен по WEBHOOK_BASE_URL.")
    await bot.session.close()


if __name__ == "__main__":
    asyncio.run(main())
