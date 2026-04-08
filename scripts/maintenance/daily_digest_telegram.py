#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Daily digest publication to the Telegram channel.
Uses the direct Telegram HTTP API helpers instead of an interactive bot runtime.
"""

import asyncio
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")

from services.daily_digest_service import generate_today_digest_text, get_today_complaints
from services.push_notification_service import send_telegram_message


async def _send_to_channel(text: str) -> bool:
    target_channel = (os.getenv("TARGET_CHANNEL") or "").strip()
    if not target_channel:
        print("[FAIL] TARGET_CHANNEL is not configured")
        return False
    return await send_telegram_message(target_channel, text, parse_mode=None)


async def main():
    print("[DailyDigest] Loading reports for today...")
    complaints = await get_today_complaints()
    print(f"[DailyDigest] Reports today: {len(complaints)}")
    digest = await generate_today_digest_text()
    print("[DailyDigest] Digest prepared.")
    if await _send_to_channel(digest):
        print("[OK] Digest published to channel", os.getenv("TARGET_CHANNEL", ""))
        return 0

    print("[FAIL] Could not publish digest")
    print("--- digest ---")
    print(digest[:500])
    return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
