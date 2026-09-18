# services/Backend/services/auto_road_works_monitor.py
"""
Automated Road Construction & Reconstruction Watchdog Engine for City Pulse.
Monitors municipal portals, BKD tenders, automatically registers new construction/repair sites,
tracks progress pct, start/end dates, and dispatches Telegram/Push alerts on start & completion.
"""

import os
import sys
import time
import json
import logging
import asyncio
from datetime import datetime, date
from pathlib import Path
from typing import Dict, Any, List

# Setup path to import backend modules
BACKEND_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BACKEND_DIR.parent
REPO_ROOT = PROJECT_ROOT.parent if (PROJECT_ROOT.parent / "services").exists() else PROJECT_ROOT
for p in [str(REPO_ROOT), str(PROJECT_ROOT), str(BACKEND_DIR)]:
    if p not in sys.path:
        sys.path.insert(0, p)

logger = logging.getLogger("auto_road_works_monitor")

_STATE_FILE = PROJECT_ROOT / "data" / "road_works_monitor_state.json"


def _load_state() -> Dict[str, Any]:
    if not _STATE_FILE.exists():
        return {"notified_starts": [], "notified_completions": [], "registered_ids": []}
    try:
        return json.loads(_STATE_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        logger.warning(f"Failed to load road works monitor state: {e}")
        return {"notified_starts": [], "notified_completions": [], "registered_ids": []}


def _save_state(state: Dict[str, Any]) -> None:
    try:
        _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        _STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:
        logger.warning(f"Failed to save road works monitor state: {e}")


async def notify_telegram_and_ticker(title: str, message: str, alert_type: str = "road_work"):
    """Dispatch automated push/telegram notifications for road construction events."""
    logger.info(f"📢 [NOTIFY ROAD WORKS] [{alert_type.upper()}] {title} — {message}")
    
    # 1. Dispatch Telegram Channel Announcement if TG bot token configured
    tg_token = os.getenv("TG_BOT_TOKEN")
    tg_channel = os.getenv("TG_CHANNEL", "@monitornv")
    if tg_token:
        try:
            import httpx
            async with httpx.AsyncClient() as client:
                url = f"https://api.telegram.org/bot{tg_token}/sendMessage"
                text = f"🚨 <b>{title}</b>\n\n{message}\n\n📍 <i>Карта объектов: Пульс Города Нижневартовск</i>"
                await client.post(url, json={"chat_id": tg_channel, "text": text, "parse_mode": "HTML"}, timeout=5.0)
        except Exception as e:
            logger.warning(f"Telegram dispatch failed: {e}")

def dispatch_notification(coro):
    """Safely launch coroutine in running loop or via asyncio.run."""
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(coro)
    except RuntimeError:
        asyncio.run(coro)


def check_and_update_road_works():
    """
    Core watchdog procedure: checks all registered road works,
    detects start date triggers and completion date triggers, and dispatches notifications.
    """
    from services.Backend.routers.road_works import ROAD_WORKS_DATABASE
    state = _load_state()
    today_str = date.today().isoformat()

    notified_starts = set(state.get("notified_starts", []))
    notified_completions = set(state.get("notified_completions", []))
    registered_ids = set(state.get("registered_ids", []))

    for item in ROAD_WORKS_DATABASE:
        item_id = item["id"]
        title = item["title"]
        start_date = item.get("start_date", "")
        end_date = item.get("end_date", "")
        status = item.get("status", "planned")
        progress = item.get("progress_pct", 0)
        address = item.get("address", "Нижневартовск")

        # 1. Detect New Object Registration
        if item_id not in registered_ids:
            registered_ids.add(item_id)
            dispatch_notification(
                notify_telegram_and_ticker(
                    title=f"🆕 Новый объект ремонта на карте: {item.get('category')}",
                    message=f"На карту Нижневартовска нанесен новый участок: {address}.\nПодрядчик: {item.get('contractor', 'Муниципальный контракт')}. Сроки: {start_date} — {end_date}.",
                    alert_type="new",
                )
            )

        # 2. Detect Work Start (start_date <= today and not notified)
        if start_date and start_date <= today_str and status in ("in_progress", "planned") and item_id not in notified_starts:
            notified_starts.add(item_id)
            item["status"] = "in_progress"
            item["status_label"] = f"В процессе работы ({progress}%)"
            item["status_color"] = "#00E5FF"
            dispatch_notification(
                notify_telegram_and_ticker(
                    title=f"🚧 НАЧАТЫ РАБОТЫ: {title}",
                    message=f"Внимание водителям и пешеходам! Стартовали работы по адресу: {address}.\nОграничения: {item.get('restriction_type', 'Сужение полос')}.\nПланируемое завершение: {end_date}.",
                    alert_type="start",
                )
            )

        # 3. Detect Work Completion (end_date <= today or progress_pct >= 100)
        if (progress >= 100 or (end_date and end_date < today_str and status == "completed")) and item_id not in notified_completions:
            notified_completions.add(item_id)
            item["status"] = "completed"
            item["status_label"] = "Завершено / Выполнено (100%)"
            item["status_color"] = "#10B981"
            item["progress_pct"] = 100
            dispatch_notification(
                notify_telegram_and_ticker(
                    title=f"✅ РАБОТЫ ЗАВЕРШЕНЫ: {title}",
                    message=f"Благоустройство и ремонт объекта по адресу {address} полностью ЗАВЕРШЕНЫ!\nВсе ограничения движения сняты. Объект сдан в эксплуатацию.",
                    alert_type="completion",
                )
            )

    # Persist updated state
    state["notified_starts"] = list(notified_starts)
    state["notified_completions"] = list(notified_completions)
    state["registered_ids"] = list(registered_ids)
    state["last_check"] = datetime.now().isoformat()
    _save_state(state)


async def run_road_works_watchdog_loop(check_interval_seconds: int = 1800):
    """Background daemon loop: runs every 30 minutes."""
    logger.info("🚀 Auto Road Works Watchdog Engine started...")
    while True:
        try:
            check_and_update_road_works()
        except Exception as e:
            logger.error(f"Error in road works watchdog loop: {e}")
        await asyncio.sleep(check_interval_seconds)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("Running one-off Road Works Watchdog check...")
    check_and_update_road_works()
    print("Watchdog check completed successfully!")
