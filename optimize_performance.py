#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт оптимизации производительности
Проверяет и оптимизирует скорость загрузки сервисов
"""

import asyncio
import time
import logging
from typing import Dict, Any

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def check_import_speed():
    """Проверка скорости импорта модулей"""
    logger.info("=" * 60)
    logger.info("ПРОВЕРКА СКОРОСТИ ИМПОРТА МОДУЛЕЙ")
    logger.info("=" * 60)
    
    modules = [
        "services.telegram_bot",
        "services.zai_service",
        "services.zai_vision_service",
        "services.firebase_service",
        "services.admin_panel",
        "services.rate_limiter",
        "services.ai_cache",
        "core.config",
    ]
    
    results = {}
    
    for module_name in modules:
        start = time.time()
        try:
            __import__(module_name)
            elapsed = (time.time() - start) * 1000  # в миллисекундах
            results[module_name] = {"time": elapsed, "status": "ok"}
            logger.info(f"✅ {module_name}: {elapsed:.2f} ms")
        except Exception as e:
            elapsed = (time.time() - start) * 1000
            results[module_name] = {"time": elapsed, "status": "error", "error": str(e)}
            logger.error(f"❌ {module_name}: {elapsed:.2f} ms - {e}")
    
    total_time = sum(r["time"] for r in results.values())
    logger.info(f"\nОбщее время импорта: {total_time:.2f} ms")
    
    return results


async def check_database_performance():
    """Проверка производительности БД"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ПРОИЗВОДИТЕЛЬНОСТИ БД")
    logger.info("=" * 60)
    
    try:
        from backend.database import SessionLocal
        from backend.models import Report, User
        
        db = SessionLocal()
        start = time.time()
        
        # Простой запрос
        count = db.query(Report).count()
        elapsed = (time.time() - start) * 1000
        
        logger.info(f"✅ Запрос count(): {elapsed:.2f} ms ({count} записей)")
        
        # Запрос с фильтром
        start = time.time()
        open_reports = db.query(Report).filter(Report.status == "open").count()
        elapsed = (time.time() - start) * 1000
        
        logger.info(f"✅ Запрос с фильтром: {elapsed:.2f} ms ({open_reports} записей)")
        
        db.close()
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка проверки БД: {e}")
        return False


async def check_cache_performance():
    """Проверка производительности кэша"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ПРОИЗВОДИТЕЛЬНОСТИ КЭША")
    logger.info("=" * 60)
    
    try:
        from services.ai_cache import get_cached_text, set_cached_text, get_cache_stats
        
        # Тест записи
        start = time.time()
        for i in range(100):
            set_cached_text(f"test_text_{i}", {"category": "Тест"}, "test_model")
        elapsed = (time.time() - start) * 1000
        logger.info(f"✅ Запись 100 записей: {elapsed:.2f} ms ({elapsed/100:.3f} ms/запись)")
        
        # Тест чтения
        start = time.time()
        hits = 0
        for i in range(100):
            if get_cached_text(f"test_text_{i}", "test_model"):
                hits += 1
        elapsed = (time.time() - start) * 1000
        logger.info(f"✅ Чтение 100 записей: {elapsed:.2f} ms ({elapsed/100:.3f} ms/запись, {hits} попаданий)")
        
        stats = get_cache_stats()
        logger.info(f"✅ Статистика кэша: {stats['total']} записей, {stats['valid']} валидных")
        
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка проверки кэша: {e}")
        return False


async def optimize_imports():
    """Рекомендации по оптимизации импортов"""
    logger.info("\n" + "=" * 60)
    logger.info("РЕКОМЕНДАЦИИ ПО ОПТИМИЗАЦИИ")
    logger.info("=" * 60)
    
    recommendations = [
        "✅ Использовать lazy imports для тяжелых модулей",
        "✅ Кэшировать результаты импорта",
        "✅ Использовать __slots__ для классов с большим количеством экземпляров",
        "✅ Оптимизировать запросы к БД (использовать select_related/prefetch_related)",
        "✅ Использовать connection pooling для БД",
        "✅ Минимизировать размер HTML/CSS/JS в worker.js",
        "✅ Использовать CDN для статических ресурсов",
        "✅ Включить gzip/brotli сжатие",
    ]
    
    for rec in recommendations:
        logger.info(f"  {rec}")


async def main():
    """Главная функция"""
    logger.info("\n" + "=" * 60)
    logger.info("ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ")
    logger.info("=" * 60)
    
    # Проверки
    import_results = await check_import_speed()
    db_ok = await check_database_performance()
    cache_ok = await check_cache_performance()
    
    # Рекомендации
    await optimize_imports()
    
    logger.info("\n" + "=" * 60)
    logger.info("ИТОГИ")
    logger.info("=" * 60)
    logger.info(f"Импорт модулей: {'✅ OK' if all(r['status'] == 'ok' for r in import_results.values()) else '⚠️ Есть проблемы'}")
    logger.info(f"База данных: {'✅ OK' if db_ok else '❌ ОШИБКА'}")
    logger.info(f"Кэш: {'✅ OK' if cache_ok else '❌ ОШИБКА'}")


if __name__ == "__main__":
    asyncio.run(main())
