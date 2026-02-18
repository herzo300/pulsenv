#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Запуск и проверка всех сервисов проекта
"""

import asyncio
import logging
import sys
import os
import subprocess
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def print_header(text):
    """Вывод заголовка"""
    print("\n" + "="*60)
    print(f"  {text}")
    print("="*60)

def check_service_running(process_name):
    """Проверка запущен ли процесс"""
    try:
        result = subprocess.run(
            ['tasklist', '/FI', f'IMAGENAME eq {process_name}'],
            capture_output=True,
            text=True,
            timeout=5
        )
        return process_name.lower() in result.stdout.lower()
    except:
        return False

async def check_worker_endpoint():
    """Проверка Worker endpoint"""
    try:
        import httpx
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://anthropic-proxy.uiredepositionherzo.workers.dev/health"
            )
            if response.status_code == 200:
                logger.info("[OK] Cloudflare Worker доступен")
                return True
            else:
                logger.error(f"[FAIL] Worker вернул {response.status_code}")
                return False
    except Exception as e:
        logger.error(f"[FAIL] Worker недоступен: {e}")
        return False

def main():
    """Главная функция"""
    print_header("ЗАПУСК И ПРОВЕРКА СЕРВИСОВ")
    
    # Проверка процессов Python
    print("\n[1] Проверка запущенных процессов...")
    python_running = check_service_running("python.exe")
    if python_running:
        logger.info("[OK] Python процессы запущены")
    else:
        logger.warning("[WARN] Python процессы не найдены")
    
    # Проверка Worker
    print("\n[2] Проверка Cloudflare Worker...")
    try:
        result = asyncio.run(check_worker_endpoint())
        if result:
            logger.info("[OK] Worker проверен")
        else:
            logger.warning("[WARN] Worker недоступен")
    except Exception as e:
        logger.error(f"[ERROR] Ошибка проверки Worker: {e}")
    
    # Инструкции по запуску
    print("\n" + "="*60)
    print("  ИНСТРУКЦИИ ПО ЗАПУСКУ")
    print("="*60)
    print("\n1. Запустите Telegram бота:")
    print("   py start_telegram_bot.py")
    print("\n2. Запустите мониторинг:")
    print("   py start_all_monitoring.py")
    print("\n3. Или используйте batch файл:")
    print("   start_all.bat")
    print("\n4. Проверьте Worker в браузере:")
    print("   https://anthropic-proxy.uiredepositionherzo.workers.dev/app?v=" + str(int(time.time())))
    print("\n" + "="*60)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nПрервано пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Ошибка: {e}", exc_info=True)
        sys.exit(1)
