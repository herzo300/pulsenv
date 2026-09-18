"""Main entry point for the monitoring system."""

import asyncio
import logging
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Ensure UTF-8 output on Windows consoles
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

from dotenv import load_dotenv

load_dotenv()

from telethon import events

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

from services.realtime_guard import RealtimeGuard
from services.vk_monitor_service import (
    VK_GROUPS,
    VK_SERVICE_TOKEN,
    poll_all_groups,
)

from .config import (
    API_HASH,
    API_ID,
    CHANNELS_TO_MONITOR,
    EMOJI,
    MONITOR_POLL_INTERVAL_SECONDS,
    TARGET_CHANNEL,
)
from .pipeline import stats as stats_ref
from .telegram_handler import handle_telegram_message
from .vk_handler import handle_vk_complaint


async def main() -> bool:
    global tg_guard
    logger.info("=" * 60)
    logger.info("🚀 ЕДИНЫЙ МОНИТОРИНГ: Telegram + VK → AI → SQLite + @monitornv")
    logger.info("=" * 60)

    if not API_ID or not API_HASH:
        logger.error("❌ TG_API_ID или TG_API_HASH не найдены в .env")
        return False

    # Инициализация RealtimeGuard
    guard = RealtimeGuard()
    logger.info(f"⏱️ Время запуска (UTC): {guard.startup_time.isoformat()}")
    logger.info("🛡️ RealtimeGuard: только новые сообщения + дедупликация")

    # Share guard with telegram_handler module
    import services.monitoring.telegram_handler as tg_handler_mod

    tg_handler_mod.guard = guard

    from .telegram_client_factory import (
        build_monitoring_telegram_client,
        describe_telegram_transport,
    )

    session_path = os.getenv("MONITORING_SESSION_PATH", "monitoring_session")
    client = build_monitoring_telegram_client(session_path)
    logger.info("Telegram transport: %s", describe_telegram_transport())
    vk_task = None
    digest_task = None

    try:
        # Viseron NVR: события приходят webhook → backend (/api/nvr/viseron/webhook)
        # Если сессия валидна — подключится без ввода кода
        # Если нет — запустите сначала: py auth_telethon.py
        await client.connect()
        tg_authorized = await client.is_user_authorized()
        if not tg_authorized:
            logger.warning("⚠️ Сессия Telegram не авторизована! Запустите: py auth_telethon.py для привязки.")
            logger.warning("❌ Мониторинг Telegram-каналов пропускается. Будет работать только VK-мониторинг.")
        else:
            logger.info("✅ Telegram подключён и авторизован")
            me = await client.get_me()
            logger.info(f"👤 {me.first_name} (@{me.username})")

            # Проверяем целевой канал
            if TARGET_CHANNEL:
                try:
                    ch = await client.get_entity(TARGET_CHANNEL)
                    logger.info(f"✅ Целевой канал: {ch.title}")
                except Exception as e:
                    logger.error(f"❌ Канал {TARGET_CHANNEL}: {e}")

        # --- Telegram мониторинг ---
        if tg_authorized:
            logger.info(f"\n📡 TELEGRAM: {len(CHANNELS_TO_MONITOR)} каналов")
            for c in CHANNELS_TO_MONITOR:
                logger.info(f"   • {c}")

            @client.on(events.NewMessage(chats=CHANNELS_TO_MONITOR))
            async def tg_handler(event):
                await handle_telegram_message(client, event)
                _print_stats_periodic()

        # --- VK мониторинг ---
        poll_interval = MONITOR_POLL_INTERVAL_SECONDS
        if VK_SERVICE_TOKEN:
            logger.info(f"\n🔵 VK: {len(VK_GROUPS)} пабликов")
            for short_name, gid, name in VK_GROUPS:
                logger.info(f"   • {name}")

            async def vk_callback(complaint_data):
                await handle_vk_complaint(client, complaint_data)

            vk_task = asyncio.create_task(
                poll_all_groups(
                    on_complaint=vk_callback,
                    poll_interval=poll_interval,
                    startup_time=guard.startup_time,
                )
            )
            logger.info("VK polling started (interval %s sec)", poll_interval)
        else:
            logger.warning("⚠️ VK_SERVICE_TOKEN не задан — VK мониторинг отключён")
            logger.warning(
                "   Получите токен: https://dev.vk.com → Мои приложения → Сервисный ключ"
            )
            vk_task = None

        # Data storage: SQLite + PostgreSQL runtime
        logger.info("✅ Данные сохраняются в SQLite + PostgreSQL runtime")

        logger.info("\n" + "=" * 60)
        logger.info("🤖 Мониторинг запущен! Ожидание сообщений...")
        logger.info("⏹️  Ctrl+C для остановки")
        logger.info("=" * 60)

        # --- Digest Scheduler ---
        logger.info("📊 Запуск почасового планировщика дайджеста...")
        from services.ai.daily_digest_ai import digest_scheduler
        digest_task = asyncio.create_task(digest_scheduler(client))

        # --- Animal Monitor Task ---
        logger.info("🐾 Запуск периодического мониторинга потерянных животных...")
        from services.Backend.services.parse_vk_animals import run_monitoring_cycle

        async def animal_monitor_loop():
            while True:
                try:
                    await asyncio.to_thread(run_monitoring_cycle)
                except Exception as animal_err:
                    logger.error(f"Ошибка в цикле мониторинга животных: {animal_err}")
                await asyncio.sleep(1800)

        animal_monitor_task = asyncio.create_task(animal_monitor_loop())

        if tg_authorized:
            await client.run_until_disconnected()
        else:
            logger.info("📡 Telegram не авторизован. Входим в бесконечный цикл ожидания для VK-мониторинга...")
            while True:
                await asyncio.sleep(3600)

    except KeyboardInterrupt:
        logger.info("⏹️ Остановка...")
        return False
    except Exception as e:
        logger.error(f"❌ {e}", exc_info=True)
        return True
    finally:
        _print_final_stats()
        if vk_task is not None:
            vk_task.cancel()
        if digest_task is not None:
            digest_task.cancel()
        if 'animal_monitor_task' in locals() and animal_monitor_task is not None:
            animal_monitor_task.cancel()
        await client.disconnect()

    return True


async def run_forever():
    restart_delay = max(5, int(os.getenv("MONITOR_RESTART_DELAY_SECONDS", "30")))
    while True:
        should_restart = await main()
        if not should_restart:
            break
        logger.warning(
            "Monitoring stopped unexpectedly; reconnecting in %s sec",
            restart_delay,
        )
        await asyncio.sleep(restart_delay)


_stats_counter = 0


def _print_stats_periodic():
    global _stats_counter
    _stats_counter += 1
    if _stats_counter % 10 == 0:
        total = stats_ref["tg_total"] + stats_ref["vk_total"]
        published = stats_ref["tg_published"] + stats_ref["vk_published"]
        # Access guard stats through telegram_handler module
        import services.monitoring.telegram_handler as tg_mod

        gs = tg_mod.guard.stats if tg_mod.guard else None
        guard_info = (
            f" | 🛡️ Старые: {gs.skipped_old} Дубли: {gs.skipped_duplicate}" if gs else ""
        )
        logger.info(
            f"📊 TG: {stats_ref['tg_published']}/{stats_ref['tg_total']} | "
            f"VK: {stats_ref['vk_published']}/{stats_ref['vk_total']} | "
            f"Всего: {published}/{total}{guard_info}"
        )


def _print_final_stats():
    total = stats_ref["tg_total"] + stats_ref["vk_total"]
    published = stats_ref["tg_published"] + stats_ref["vk_published"]
    logger.info("\n📊 ИТОГО:")
    logger.info(
        f"   Telegram: {stats_ref['tg_published']}/{stats_ref['tg_total']} опубликовано"
    )
    logger.info(
        f"   VK: {stats_ref['vk_published']}/{stats_ref['vk_total']} опубликовано"
    )
    logger.info(f"   Всего: {published}/{total}")
    for cat, cnt in sorted(
        stats_ref["by_category"].items(), key=lambda x: x[1], reverse=True
    ):
        logger.info(f"   {EMOJI.get(cat, '❔')} {cat}: {cnt}")


if __name__ == "__main__":
    try:
        asyncio.run(run_forever())
    except KeyboardInterrupt:
        logger.info("⏹️ Мониторинг остановлен")
