#!/usr/bin/env python3
"""
Тестирование команд Telegram бота
"""

import asyncio
import os
from dotenv import load_dotenv
from aiogram import Bot
from aiogram.types import BotCommand, BotCommandScopeDefault

load_dotenv()

BOT_TOKEN = os.getenv('TG_BOT_TOKEN')

async def test_bot():
    """Тестирует бота и его команды"""
    bot = Bot(token=BOT_TOKEN)
    
    try:
        # Получаем информацию о боте
        me = await bot.get_me()
        print(f"✅ Бот подключен: @{me.username}")
        print(f"   ID: {me.id}")
        print(f"   Имя: {me.first_name}\n")
        
        # Получаем текущие команды
        commands = await bot.get_my_commands()
        print("📋 Текущие команды бота:")
        if commands:
            for cmd in commands:
                print(f"   /{cmd.command} - {cmd.description}")
        else:
            print("   Команды не установлены")
        
        print("\n" + "="*50)
        print("🔧 Устанавливаем команды...")
        print("="*50 + "\n")
        
        # Устанавливаем команды
        new_commands = [
            BotCommand(command="start", description="🏠 Главное меню"),
            BotCommand(command="help", description="❓ Помощь"),
            BotCommand(command="new", description="📝 Новая жалоба"),
            BotCommand(command="my", description="📋 Мои жалобы"),
            BotCommand(command="stats", description="📊 Статистика"),
            BotCommand(command="map", description="🗺️ Карта проблем"),
            BotCommand(command="categories", description="🏷️ Категории"),
            BotCommand(command="about", description="ℹ️ О проекте"),
        ]
        
        await bot.set_my_commands(new_commands, scope=BotCommandScopeDefault())
        print("✅ Команды установлены!\n")
        
        # Проверяем установленные команды
        commands = await bot.get_my_commands()
        print("📋 Установленные команды:")
        for cmd in commands:
            print(f"   /{cmd.command} - {cmd.description}")
        
        print("\n" + "="*50)
        print("✅ ТЕСТ ЗАВЕРШЕН УСПЕШНО!")
        print("="*50)
        print("\n💡 Теперь откройте @pulsenvbot в Telegram:")
        print("   1. Нажмите на кнопку меню (☰)")
        print("   2. Увидите все 8 команд")
        print("   3. Попробуйте команду /map")
        print("   4. Нажмите кнопку 'Открыть карту'")
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        import traceback
        traceback.print_exc()
    finally:
        await bot.session.close()

if __name__ == "__main__":
    print("🧪 Тестирование Telegram бота...\n")
    asyncio.run(test_bot())
