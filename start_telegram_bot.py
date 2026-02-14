#!/usr/bin/env python3
"""Запуск Telegram бота — Пульс города Нижневартовск"""

import asyncio
import logging
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def run():
    from services.telegram_bot import bot, main as bot_main

    info = await bot.get_me()
    logger.info(f"✅ Бот: @{info.username} (ID: {info.id}, {info.first_name})")

    await bot_main()


if __name__ == "__main__":
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        logger.info("⏹️ Бот остановлен")
