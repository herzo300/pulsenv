#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Принудительное обновление бота в Telegram
Удаляет старые команды и устанавливает новые
"""

import asyncio
import logging
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def force_update_bot():
    """Принудительное обновление бота"""
    logger.info("=" * 60)
    logger.info("ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ БОТА")
    logger.info("=" * 60)
    
    try:
        from services.telegram_bot import bot
        from aiogram.types import BotCommand, BotCommandScopeDefault
        
        # Проверяем бота
        info = await bot.get_me()
        logger.info(f"Бот: @{info.username} (ID: {info.id})")
        
        # Удаляем ВСЕ старые команды
        logger.info("\nУдаление старых команд...")
        try:
            await bot.delete_my_commands(scope=BotCommandScopeDefault())
            logger.info("✅ Старые команды удалены")
        except Exception as e:
            logger.warning(f"⚠️ Ошибка удаления команд (может быть нормально): {e}")
        
        # Ждем немного
        await asyncio.sleep(1)
        
        # Устанавливаем новые команды
        logger.info("\nУстановка новых команд...")
        commands = [
            BotCommand(command="start", description="🏠 Главная"),
            BotCommand(command="help", description="❓ Справка"),
            BotCommand(command="new", description="📝 Новая жалоба"),
            BotCommand(command="map", description="🗺️ Карта"),
            BotCommand(command="info", description="📊 Инфографика"),
            BotCommand(command="profile", description="👤 Профиль"),
        ]
        
        await bot.set_my_commands(commands, scope=BotCommandScopeDefault())
        logger.info("✅ Новые команды установлены")
        
        # Проверяем установленные команды
        logger.info("\nПроверка установленных команд...")
        installed = await bot.get_my_commands(scope=BotCommandScopeDefault())
        logger.info(f"Установлено команд: {len(installed)}")
        for cmd in installed:
            logger.info(f"  /{cmd.command} - {cmd.description}")
        
        # Обновляем описание бота (если нужно)
        logger.info("\nОбновление описания бота...")
        try:
            await bot.set_my_description(
                "Пульс города — Нижневартовск. AI мониторинг городских проблем."
            )
            logger.info("✅ Описание обновлено")
        except Exception as e:
            logger.warning(f"⚠️ Не удалось обновить описание: {e}")
        
        logger.info("\n" + "=" * 60)
        logger.info("✅ БОТ УСПЕШНО ОБНОВЛЕН!")
        logger.info("=" * 60)
        logger.info("\n💡 Инструкции:")
        logger.info("   1. В Telegram отправьте /start")
        logger.info("   2. Должно появиться меню с кнопками: Профиль и Вход")
        logger.info("   3. Если видите старое меню:")
        logger.info("      - Закройте Telegram полностью")
        logger.info("      - Откройте заново")
        logger.info("      - Отправьте /start еще раз")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Ошибка обновления бота: {e}", exc_info=True)
        return False


if __name__ == "__main__":
    try:
        success = asyncio.run(force_update_bot())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("\n⏹️ Прервано пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)
