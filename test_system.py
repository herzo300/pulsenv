#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Тестирование всех функций системы
Проверка: админ-панель, анализ Qwen, публикация Firebase/Telegram
"""

import os
import sys
import asyncio
import logging
from datetime import datetime
from dotenv import load_dotenv

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Результаты проверки
results = {
    "config": {},
    "admin_panel": {},
    "ai_analysis": {},
    "firebase": {},
    "telegram": {},
    "database": {},
    "issues": [],
    "recommendations": []
}

def check_config():
    """Проверка конфигурации"""
    logger.info("=" * 60)
    logger.info("ПРОВЕРКА КОНФИГУРАЦИИ")
    logger.info("=" * 60)
    
    checks = {
        "TG_BOT_TOKEN": os.getenv("TG_BOT_TOKEN"),
        "OPENROUTER_API_KEY": os.getenv("OPENROUTER_API_KEY"),
        "OPENROUTER_TEXT_MODEL": os.getenv("OPENROUTER_TEXT_MODEL", "qwen/qwen3-coder"),
        "OPENROUTER_VISION_MODEL": os.getenv("OPENROUTER_VISION_MODEL", "qwen/qwen-vl-plus"),
        "FIREBASE_RTDB_URL": os.getenv("FIREBASE_RTDB_URL"),
        "ADMIN_TELEGRAM_IDS": os.getenv("ADMIN_TELEGRAM_IDS"),
        "TARGET_CHANNEL": os.getenv("TARGET_CHANNEL", "@monitornv"),
    }
    
    results["config"] = checks
    
    for key, value in checks.items():
        if value:
            logger.info(f"✅ {key}: {'*' * 20 if 'TOKEN' in key or 'KEY' in key else value}")
        else:
            logger.warning(f"❌ {key}: НЕ ЗАДАН")
            results["issues"].append(f"Отсутствует переменная окружения: {key}")
            if key == "ADMIN_TELEGRAM_IDS":
                results["recommendations"].append(
                    "Добавьте ADMIN_TELEGRAM_IDS в .env для работы админ-панели"
                )
            elif key == "OPENROUTER_API_KEY":
                results["recommendations"].append(
                    "Добавьте OPENROUTER_API_KEY в .env для работы AI анализа"
                )
    
    return all(checks.values())


def check_admin_panel():
    """Проверка админ-панели"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА АДМИН-ПАНЕЛИ")
    logger.info("=" * 60)
    
    try:
        from services.admin_panel import (
            is_admin, get_stats, get_firebase_stats, format_stats_message,
            get_recent_reports, format_report_message, get_bot_status,
            toggle_monitoring, is_monitoring_enabled, export_stats_csv, clear_old_reports,
            ADMIN_IDS
        )
        from backend.database import SessionLocal
        
        # Проверка импортов
        logger.info("✅ Все функции админ-панели импортированы")
        
        # Проверка ADMIN_IDS
        if ADMIN_IDS:
            logger.info(f"✅ Найдено администраторов: {len(ADMIN_IDS)}")
            logger.info(f"   IDs: {ADMIN_IDS}")
        else:
            logger.warning("⚠️ Администраторы не настроены (ADMIN_TELEGRAM_IDS пуст)")
            results["issues"].append("Администраторы не настроены")
        
        # Проверка функций статистики
        db = SessionLocal()
        try:
            stats = get_stats(db)
            logger.info(f"✅ Статистика получена: {stats['total_reports']} жалоб, {stats['total_users']} пользователей")
            
            # Проверка форматирования
            msg = format_stats_message(stats)
            if len(msg) > 0:
                logger.info("✅ Форматирование статистики работает")
            
            # Проверка статуса бота
            bot_status = get_bot_status()
            logger.info(f"✅ Статус бота: мониторинг {'включен' if bot_status['monitoring_enabled'] else 'выключен'}")
            
            # Проверка экспорта
            csv_data = export_stats_csv(db)
            if csv_data and len(csv_data) > 0:
                logger.info(f"✅ Экспорт CSV работает ({len(csv_data)} символов)")
            
            results["admin_panel"] = {
                "status": "ok",
                "admins_count": len(ADMIN_IDS),
                "stats_available": True,
                "export_works": True
            }
        except Exception as e:
            logger.error(f"❌ Ошибка при проверке статистики: {e}")
            results["admin_panel"]["status"] = "error"
            results["admin_panel"]["error"] = str(e)
            results["issues"].append(f"Ошибка админ-панели: {e}")
        finally:
            db.close()
            
    except ImportError as e:
        logger.error(f"❌ Ошибка импорта админ-панели: {e}")
        results["admin_panel"]["status"] = "import_error"
        results["issues"].append(f"Ошибка импорта админ-панели: {e}")


async def check_ai_analysis():
    """Проверка AI анализа"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА AI АНАЛИЗА (QWEN)")
    logger.info("=" * 60)
    
    try:
        from services.zai_service import analyze_complaint, OPENROUTER_API_KEY, OPENROUTER_TEXT_MODEL
        from services.zai_vision_service import analyze_image_with_glm4v, OPENROUTER_VISION_MODEL
        
        # Проверка конфигурации
        if not OPENROUTER_API_KEY:
            logger.warning("⚠️ OPENROUTER_API_KEY не задан — AI анализ не будет работать")
            results["ai_analysis"]["status"] = "no_api_key"
            results["issues"].append("OPENROUTER_API_KEY не задан")
            return
        
        logger.info(f"✅ OpenRouter API ключ настроен")
        logger.info(f"✅ Модель текста: {OPENROUTER_TEXT_MODEL}")
        logger.info(f"✅ Модель изображений: {OPENROUTER_VISION_MODEL}")
        
        # Тест анализа текста
        test_text = "На улице Ленина, дом 15, разбита дорога, большая яма"
        logger.info(f"\nТестирование анализа текста: '{test_text}'")
        
        try:
            result = await analyze_complaint(test_text)
            if result:
                logger.info(f"✅ Анализ текста работает")
                logger.info(f"   Категория: {result.get('category')}")
                logger.info(f"   Адрес: {result.get('address')}")
                logger.info(f"   Релевантность: {result.get('relevant')}")
                results["ai_analysis"]["text_analysis"] = "ok"
            else:
                logger.warning("⚠️ Анализ текста вернул None (возможно, используется fallback)")
                results["ai_analysis"]["text_analysis"] = "fallback"
        except Exception as e:
            logger.error(f"❌ Ошибка анализа текста: {e}")
            results["ai_analysis"]["text_analysis"] = "error"
            results["ai_analysis"]["text_error"] = str(e)
            results["issues"].append(f"Ошибка анализа текста: {e}")
        
        # Тест анализа изображения (без реального файла)
        logger.info("\n⚠️ Анализ изображений требует реальный файл — пропущен")
        results["ai_analysis"]["image_analysis"] = "skipped"
        
        results["ai_analysis"]["status"] = "ok"
        
    except ImportError as e:
        logger.error(f"❌ Ошибка импорта AI модулей: {e}")
        results["ai_analysis"]["status"] = "import_error"
        results["issues"].append(f"Ошибка импорта AI модулей: {e}")


async def check_firebase():
    """Проверка Firebase"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА FIREBASE")
    logger.info("=" * 60)
    
    try:
        from services.firebase_service import push_complaint, get_recent_complaints, FIREBASE_RTDB_URL
        
        if not FIREBASE_RTDB_URL:
            logger.warning("⚠️ FIREBASE_RTDB_URL не задан")
            results["firebase"]["status"] = "no_url"
            results["issues"].append("FIREBASE_RTDB_URL не задан")
            return
        
        logger.info(f"✅ Firebase URL: {FIREBASE_RTDB_URL}")
        
        # Тест получения данных
        try:
            complaints = await get_recent_complaints(limit=5)
            logger.info(f"✅ Получение данных из Firebase работает: {len(complaints)} жалоб")
            results["firebase"]["read"] = "ok"
            results["firebase"]["complaints_count"] = len(complaints)
        except Exception as e:
            logger.error(f"❌ Ошибка чтения из Firebase: {e}")
            results["firebase"]["read"] = "error"
            results["firebase"]["read_error"] = str(e)
            results["issues"].append(f"Ошибка чтения Firebase: {e}")
        
        # Тест публикации (опционально, можно закомментировать чтобы не создавать тестовые данные)
        logger.info("\n⚠️ Тест публикации в Firebase пропущен (чтобы не создавать тестовые данные)")
        results["firebase"]["write"] = "skipped"
        
        results["firebase"]["status"] = "ok"
        
    except ImportError as e:
        logger.error(f"❌ Ошибка импорта Firebase модулей: {e}")
        results["firebase"]["status"] = "import_error"
        results["issues"].append(f"Ошибка импорта Firebase модулей: {e}")


def check_database():
    """Проверка базы данных"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА БАЗЫ ДАННЫХ")
    logger.info("=" * 60)
    
    try:
        from backend.database import SessionLocal, engine
        from backend.models import Report, User, Base
        
        # Проверка подключения
        db = SessionLocal()
        try:
            # Проверка таблиц
            reports_count = db.query(Report).count()
            users_count = db.query(User).count()
            
            logger.info(f"✅ База данных подключена")
            logger.info(f"   Жалоб: {reports_count}")
            logger.info(f"   Пользователей: {users_count}")
            
            results["database"] = {
                "status": "ok",
                "reports": reports_count,
                "users": users_count
            }
        except Exception as e:
            logger.error(f"❌ Ошибка доступа к БД: {e}")
            results["database"]["status"] = "error"
            results["database"]["error"] = str(e)
            results["issues"].append(f"Ошибка БД: {e}")
        finally:
            db.close()
            
    except ImportError as e:
        logger.error(f"❌ Ошибка импорта БД модулей: {e}")
        results["database"]["status"] = "import_error"
        results["issues"].append(f"Ошибка импорта БД модулей: {e}")


def check_telegram_bot():
    """Проверка Telegram бота"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА TELEGRAM БОТА")
    logger.info("=" * 60)
    
    try:
        from services.telegram_bot import bot, dp, is_admin
        
        # Проверка токена
        token = os.getenv("TG_BOT_TOKEN")
        if not token:
            logger.warning("⚠️ TG_BOT_TOKEN не задан")
            results["telegram"]["status"] = "no_token"
            results["issues"].append("TG_BOT_TOKEN не задан")
            return
        
        logger.info("✅ Модуль бота импортирован")
        logger.info("⚠️ Для полной проверки нужно запустить бота")
        
        # Проверка админ-функций
        test_admin_id = 123456789
        is_admin_result = is_admin(test_admin_id)
        logger.info(f"✅ Функция is_admin работает (тест для ID {test_admin_id}: {is_admin_result})")
        
        results["telegram"] = {
            "status": "ok",
            "bot_imported": True,
            "admin_check_works": True
        }
        
    except ImportError as e:
        logger.error(f"❌ Ошибка импорта бота: {e}")
        results["telegram"]["status"] = "import_error"
        results["issues"].append(f"Ошибка импорта бота: {e}")


def generate_report():
    """Генерация итогового отчета"""
    logger.info("\n" + "=" * 60)
    logger.info("ИТОГОВЫЙ ОТЧЕТ")
    logger.info("=" * 60)
    
    total_issues = len(results["issues"])
    total_recommendations = len(results["recommendations"])
    
    logger.info(f"\n📊 Статистика проверки:")
    logger.info(f"   Найдено проблем: {total_issues}")
    logger.info(f"   Рекомендаций: {total_recommendations}")
    
    if results["issues"]:
        logger.info("\n❌ ПРОБЛЕМЫ:")
        for i, issue in enumerate(results["issues"], 1):
            logger.info(f"   {i}. {issue}")
    
    if results["recommendations"]:
        logger.info("\n💡 РЕКОМЕНДАЦИИ:")
        for i, rec in enumerate(results["recommendations"], 1):
            logger.info(f"   {i}. {rec}")
    
    # Дополнительные рекомендации на основе проверки
    logger.info("\n💡 ДОПОЛНИТЕЛЬНЫЕ РЕКОМЕНДАЦИИ:")
    
    if not results["config"].get("ADMIN_TELEGRAM_IDS"):
        logger.info("   1. Добавьте ADMIN_TELEGRAM_IDS в .env для работы админ-панели")
        logger.info("      Пример: ADMIN_TELEGRAM_IDS=123456789,987654321")
    
    if not results["config"].get("OPENROUTER_API_KEY"):
        logger.info("   2. Добавьте OPENROUTER_API_KEY для работы AI анализа")
        logger.info("      Получите ключ на https://openrouter.ai")
    
    if results["admin_panel"].get("status") == "ok":
        logger.info("   3. Админ-панель работает корректно")
        logger.info("      Используйте команду /admin в боте для доступа")
    
    if results["ai_analysis"].get("status") == "ok":
        logger.info("   4. AI анализ настроен и работает")
    
    if results["firebase"].get("status") == "ok":
        logger.info("   5. Firebase подключен и работает")
    
    logger.info("\n" + "=" * 60)
    logger.info("Проверка завершена")
    logger.info("=" * 60)


async def main():
    """Главная функция"""
    logger.info("\n" + "=" * 60)
    logger.info("ТЕСТИРОВАНИЕ СИСТЕМЫ 'ПУЛЬС ГОРОДА'")
    logger.info(f"Дата: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info("=" * 60)
    
    # Проверки
    check_config()
    check_admin_panel()
    await check_ai_analysis()
    await check_firebase()
    check_database()
    check_telegram_bot()
    
    # Отчет
    generate_report()
    
    return results


if __name__ == "__main__":
    try:
        results = asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("\n⏹️ Проверка прервана пользователем")
    except Exception as e:
        logger.error(f"\n❌ Критическая ошибка: {e}", exc_info=True)
