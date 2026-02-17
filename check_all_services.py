#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Проверка работоспособности всех сервисов
"""

import asyncio
import logging
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def check_telegram_bot():
    """Проверка Telegram бота"""
    logger.info("=" * 60)
    logger.info("ПРОВЕРКА TELEGRAM БОТА")
    logger.info("=" * 60)
    
    try:
        from services.telegram_bot import bot, setup_menu
        from core.config import TG_BOT_TOKEN
        
        if not TG_BOT_TOKEN:
            logger.error("❌ TG_BOT_TOKEN не задан")
            return False
        
        info = await bot.get_me()
        logger.info(f"✅ Бот: @{info.username} (ID: {info.id})")
        
        await setup_menu()
        logger.info("✅ Команды бота установлены")
        
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка проверки бота: {e}")
        return False


async def check_ai_services():
    """Проверка AI сервисов"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА AI СЕРВИСОВ")
    logger.info("=" * 60)
    
    try:
        from services.zai_service import analyze_complaint, OPENROUTER_API_KEY
        from services.zai_vision_service import analyze_image_with_glm4v
        
        if not OPENROUTER_API_KEY:
            logger.warning("⚠️ OPENROUTER_API_KEY не задан")
            return False
        
        logger.info("✅ AI сервисы импортированы")
        logger.info(f"   Модель текста: qwen/qwen3-coder")
        logger.info(f"   Модель изображений: qwen/qwen-vl-plus")
        
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка проверки AI: {e}")
        return False


async def check_database():
    """Проверка базы данных"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА БАЗЫ ДАННЫХ")
    logger.info("=" * 60)
    
    try:
        from backend.database import SessionLocal
        from backend.models import Report, User
        
        db = SessionLocal()
        try:
            reports_count = db.query(Report).count()
            users_count = db.query(User).count()
            
            logger.info(f"✅ База данных работает")
            logger.info(f"   Жалоб: {reports_count}")
            logger.info(f"   Пользователей: {users_count}")
            
            return True
        finally:
            db.close()
    except Exception as e:
        logger.error(f"❌ Ошибка проверки БД: {e}")
        return False


async def check_admin_panel():
    """Проверка админ-панели"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА АДМИН-ПАНЕЛИ")
    logger.info("=" * 60)
    
    try:
        from services.admin_panel import is_admin, get_stats, ADMIN_IDS
        from backend.database import SessionLocal
        
        logger.info(f"✅ Админ-панель работает")
        logger.info(f"   Администраторов: {len(ADMIN_IDS)}")
        
        db = SessionLocal()
        try:
            stats = get_stats(db)
            logger.info(f"   Статистика доступна: {stats['total_reports']} жалоб")
        finally:
            db.close()
        
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка проверки админ-панели: {e}")
        return False


async def check_cache_and_queue():
    """Проверка кэша и очереди"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА КЭША И ОЧЕРЕДИ")
    logger.info("=" * 60)
    
    try:
        from services.ai_cache import get_cache_stats
        from services.firebase_queue import get_queue_stats
        
        cache_stats = get_cache_stats()
        queue_stats = get_queue_stats()
        
        logger.info(f"✅ Кэш AI: {cache_stats['total']} записей")
        logger.info(f"✅ Очередь Firebase: {queue_stats['size']} записей")
        
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка проверки кэша/очереди: {e}")
        return False


async def main():
    """Главная функция"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ВСЕХ СЕРВИСОВ")
    logger.info("=" * 60)
    
    results = {
        "telegram_bot": await check_telegram_bot(),
        "ai_services": await check_ai_services(),
        "database": await check_database(),
        "admin_panel": await check_admin_panel(),
        "cache_queue": await check_cache_and_queue(),
    }
    
    logger.info("\n" + "=" * 60)
    logger.info("ИТОГИ ПРОВЕРКИ")
    logger.info("=" * 60)
    
    for service, status in results.items():
        status_text = "✅ OK" if status else "❌ FAIL"
        logger.info(f"{status_text} {service}")
    
    total_ok = sum(1 for s in results.values() if s)
    total = len(results)
    
    logger.info(f"\nРезультат: {total_ok}/{total} сервисов работают")
    
    if all(results.values()):
        logger.info("\n✅ Все сервисы работают корректно!")
        return 0
    else:
        logger.warning("\n⚠️ Некоторые сервисы требуют внимания")
        return 1


if __name__ == "__main__":
    try:
        exit_code = asyncio.run(main())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("\n⏹️ Прервано пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)
