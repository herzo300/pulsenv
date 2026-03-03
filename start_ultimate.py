#!/usr/bin/env python3
"""
🌟 Ultimate Bot — Пульс города Нижневартовск
Основной исполнительный скрипт проекта.
"""

import os
import sys
import asyncio
import logging

# Принудительно UTF-8 для корректной работы с эмодзи в консоли Windows
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Добавляем корневую директорию проекта в путь импорта
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from services.ultimate_bot import main as start_bot

if __name__ == "__main__":
    logging.info("🌟 Запуск Ultimate Bot...")
    try:
        asyncio.run(start_bot())
    except KeyboardInterrupt:
        logging.info("🛑 Бот остановлен пользователем.")
    except Exception as e:
        logging.error(f"💥 Критическая ошибка: {e}")
