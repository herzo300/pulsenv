#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ежедневная сводка в Telegram-канал: жалобы и происшествия за день,
краткий анализ городской ситуации и советы по решению.

Запуск в конце дня (например 23:00 MSK или по cron):
  py scripts/maintenance/daily_digest_telegram.py

Переменные .env: TG_BOT_TOKEN, TARGET_CHANNEL, FIREBASE_RTDB_URL.
"""

import asyncio
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv
load_dotenv(ROOT / ".env")

from services.daily_digest_service import get_today_complaints, generate_today_digest_text


async def _send_to_channel(text: str) -> bool:
    from aiogram import Bot
    from core.config import TG_BOT_TOKEN, TARGET_CHANNEL

    if not TG_BOT_TOKEN or not TARGET_CHANNEL:
        print("[FAIL] TG_BOT_TOKEN или TARGET_CHANNEL не заданы")
        return False
    bot = Bot(token=TG_BOT_TOKEN)
    try:
        await bot.send_message(TARGET_CHANNEL, text, parse_mode=None)
        return True
    except Exception as e:
        print(f"[FAIL] Отправка в канал: {e}")
        return False
    finally:
        await bot.session.close()


async def main():
    print("[DailyDigest] Загрузка жалоб за сегодня...")
    complaints = await get_today_complaints()
    print(f"[DailyDigest] Жалоб за день: {len(complaints)}")
    digest = await generate_today_digest_text()
    print("[DailyDigest] Текст сводки сформирован.")
    if await _send_to_channel(digest):
        print("[OK] Сводка опубликована в канал", os.getenv("TARGET_CHANNEL", ""))
    else:
        print("[FAIL] Не удалось опубликовать")
        print("--- digest ---")
        print(digest[:500])
        return 1
    return 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
