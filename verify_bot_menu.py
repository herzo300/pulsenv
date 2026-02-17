#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Проверка меню бота - убедиться что оно правильное
"""

import asyncio
import logging
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def verify_menu():
    """Проверка меню бота"""
    logger.info("=" * 60)
    logger.info("ПРОВЕРКА МЕНЮ БОТА")
    logger.info("=" * 60)
    
    try:
        from services.telegram_bot import bot, main_kb
        from aiogram.types import BotCommandScopeDefault
        
        # Проверяем бота
        info = await bot.get_me()
        logger.info(f"Бот: @{info.username} (ID: {info.id})")
        
        # Проверяем установленные команды
        logger.info("\nУстановленные команды:")
        commands = await bot.get_my_commands(scope=BotCommandScopeDefault())
        for cmd in commands:
            logger.info(f"  /{cmd.command} - {cmd.description}")
        
        # Проверяем функцию main_kb()
        logger.info("\nПроверка функции main_kb():")
        kb = main_kb()
        logger.info(f"Тип: {type(kb)}")
        logger.info(f"Клавиатура: {kb.keyboard}")
        
        # Проверяем количество кнопок
        total_buttons = sum(len(row) for row in kb.keyboard)
        logger.info(f"Всего кнопок: {total_buttons}")
        
        # Проверяем текст кнопок
        button_texts = []
        for row in kb.keyboard:
            for btn in row:
                button_texts.append(btn.text)
        
        logger.info(f"Текст кнопок: {button_texts}")
        
        # Проверяем что только 2 кнопки
        expected_buttons = ["👤 Профиль", "🚪 Вход"]
        if button_texts == expected_buttons:
            logger.info("\n✅ МЕНЮ ПРАВИЛЬНОЕ!")
            logger.info(f"   Найдено кнопок: {len(button_texts)}")
            logger.info(f"   Кнопки: {', '.join(button_texts)}")
        else:
            logger.error("\n❌ МЕНЮ НЕПРАВИЛЬНОЕ!")
            logger.error(f"   Ожидалось: {expected_buttons}")
            logger.error(f"   Получено: {button_texts}")
            return False
        
        logger.info("\n" + "=" * 60)
        logger.info("✅ ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ")
        logger.info("=" * 60)
        logger.info("\n💡 Для применения изменений:")
        logger.info("   1. Бот должен быть запущен")
        logger.info("   2. В Telegram отправьте /start")
        logger.info("   3. Должны появиться только 2 кнопки: Профиль и Вход")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Ошибка проверки: {e}", exc_info=True)
        return False


if __name__ == "__main__":
    try:
        success = asyncio.run(verify_menu())
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("\n⏹️ Прервано пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)
