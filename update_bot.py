#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для обновления бота в Telegram
Обновляет команды меню и проверяет версию веб-приложения
"""

import asyncio
import os
import sys
import time
import logging
from dotenv import load_dotenv

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def update_bot_commands():
    """Обновить команды меню бота"""
    try:
        from services.telegram_bot import bot, setup_menu
        
        logger.info("Обновление команд бота...")
        await setup_menu()
        logger.info("✅ Команды бота обновлены")
        
        # Проверяем информацию о боте
        info = await bot.get_me()
        logger.info(f"Бот: @{info.username} (ID: {info.id})")
        
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка обновления команд: {e}")
        return False


async def check_webapp_version():
    """Проверить версию веб-приложения"""
    import httpx
    
    CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"
    version = int(time.time())
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Проверяем /app с версионированием
            url = f"{CF_WORKER}/app?v={version}"
            logger.info(f"Проверка веб-приложения: {url}")
            
            response = await client.get(url)
            if response.status_code == 200:
                html = response.text
                # Проверяем наличие мета-тега версии
                if 'app-version' in html or 'Пульс города' in html:
                    logger.info("✅ Веб-приложение доступно")
                    logger.info(f"   Размер HTML: {len(html)} символов")
                    return True
                else:
                    logger.warning("⚠️ Веб-приложение не содержит ожидаемый контент")
                    return False
            else:
                logger.error(f"❌ Ошибка доступа к веб-приложению: {response.status_code}")
                return False
    except Exception as e:
        logger.error(f"❌ Ошибка проверки веб-приложения: {e}")
        return False


async def main():
    """Главная функция"""
    logger.info("=" * 60)
    logger.info("ОБНОВЛЕНИЕ БОТА В TELEGRAM")
    logger.info("=" * 60)
    
    # Обновляем команды
    commands_ok = await update_bot_commands()
    
    # Проверяем веб-приложение
    webapp_ok = await check_webapp_version()
    
    logger.info("\n" + "=" * 60)
    logger.info("РЕЗУЛЬТАТЫ:")
    logger.info(f"  Команды бота: {'✅ OK' if commands_ok else '❌ ОШИБКА'}")
    logger.info(f"  Веб-приложение: {'✅ OK' if webapp_ok else '❌ ОШИБКА'}")
    logger.info("=" * 60)
    
    if commands_ok and webapp_ok:
        logger.info("\n✅ Бот успешно обновлен!")
        logger.info("\n💡 Для применения изменений:")
        logger.info("   1. Перезапустите бота: py start_telegram_bot.py")
        logger.info("   2. В Telegram: /start (для обновления меню)")
        logger.info("   3. Откройте веб-приложение через команду /map или /info")
        logger.info("   4. Если видите старую версию, закройте и откройте заново")
    else:
        logger.error("\n❌ Обновление не завершено успешно")
        return 1
    
    return 0


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
