#!/usr/bin/env python3
"""
Комплексное тестирование всех функций СообщиО
Запуск: python test_all.py
"""

import os
import sys
import asyncio
import json
from datetime import datetime

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

# Цвета для вывода
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}{text}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")

def print_success(text):
    print(f"{GREEN}✅ {text}{RESET}")

def print_error(text):
    print(f"{RED}❌ {text}{RESET}")

def print_warning(text):
    print(f"{YELLOW}⚠️  {text}{RESET}")

def print_info(text):
    print(f"{BLUE}ℹ️  {text}{RESET}")

async def test_geo_service():
    """Тест геосервисов"""
    print_header("🗺️ ТЕСТ: Геосервисы")
    
    try:
        from services.geo_service import get_coordinates, make_street_view_url, reverse_geocode
        
        # Тест 1: Прямое геокодирование
        print_info("Тест 1: Геокодирование адреса")
        coords = await get_coordinates("ул. Ленина, 25")
        if coords:
            lat, lon = coords
            print_success(f"Координаты: {lat}, {lon}")
        else:
            print_error("Не удалось получить координаты")
        
        # Тест 2: Street View URL
        print_info("Тест 2: Генерация Street View URL")
        if coords:
            url = make_street_view_url(lat, lon)
            print_success(f"URL: {url}")
        
        # Тест 3: Обратное геокодирование
        print_info("Тест 3: Обратное геокодирование")
        if coords:
            address = await reverse_geocode(lat, lon)
            if address:
                print_success(f"Адрес: {address[:50]}...")
            else:
                print_warning("Обратное геокодирование не вернуло результат")
        
        return True
    except Exception as e:
        print_error(f"Ошибка: {e}")
        return False

async def test_ai_service():
    """Тест AI сервиса"""
    print_header("🤖 ТЕСТ: AI Сервис")
    
    try:
        from services.telegram_parser import analyze_complaint
        
        test_text = "На улице Ленина 25 огромная яма во дворе, машины еле проезжают"
        print_info(f"Текст: {test_text}")
        
        result = await analyze_complaint(test_text)
        
        print_success(f"Категория: {result.get('category')}")
        print_success(f"Адрес: {result.get('address')}")
        print_success(f"Резюме: {result.get('summary')}")
        
        return True
    except Exception as e:
        print_error(f"Ошибка: {e}")
        print_info("Убедитесь, что установлен ANTHROPIC_API_KEY или OPENAI_API_KEY")
        return False

async def test_database():
    """Тест базы данных"""
    print_header("💾 ТЕСТ: База данных")
    
    try:
        from backend.database import SessionLocal
        from backend.models import Report
        
        db = SessionLocal()
        
        # Тест подключения
        print_info("Проверка подключения к БД")
        count = db.query(Report).count()
        print_success(f"Подключено. Количество жалоб: {count}")
        
        db.close()
        return True
    except Exception as e:
        print_error(f"Ошибка: {e}")
        return False

async def test_api():
    """Тест API endpoints"""
    print_header("🌐 ТЕСТ: API Endpoints")
    
    try:
        import httpx
        
        base_url = "http://localhost:8000"
        
        # Тест 1: Health check
        print_info("Тест 1: Health Check")
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{base_url}/health", timeout=5.0)
            if resp.status_code == 200:
                print_success(f"API работает: {resp.json()}")
            else:
                print_error(f"API вернуло {resp.status_code}")
        
        # Тест 2: Категории
        print_info("Тест 2: Список категорий")
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{base_url}/categories", timeout=5.0)
            if resp.status_code == 200:
                cats = resp.json().get('categories', [])
                print_success(f"Получено категорий: {len(cats)}")
            else:
                print_error(f"API вернуло {resp.status_code}")
        
        # Тест 3: Статистика
        print_info("Тест 3: Статистика")
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{base_url}/stats", timeout=5.0)
            if resp.status_code == 200:
                stats = resp.json()
                print_success(f"Всего жалоб: {stats.get('total')}")
            else:
                print_error(f"API вернуло {resp.status_code}")
        
        return True
    except Exception as e:
        print_error(f"Ошибка: {e}")
        print_info("Убедитесь, что backend запущен: python run_backend.py")
        return False

async def test_telegram_connection():
    """Тест подключения к Telegram"""
    print_header("📱 ТЕСТ: Telegram API")
    
    api_id = os.getenv('TG_API_ID')
    api_hash = os.getenv('TG_API_HASH')
    
    if not api_id or not api_hash:
        print_error("TG_API_ID или TG_API_HASH не установлены")
        print_info("Получите их на https://my.telegram.org")
        return False
    
    try:
        from telethon import TelegramClient
        
        print_info("Подключение к Telegram...")
        client = TelegramClient('test_session', int(api_id), api_hash)
        
        await client.connect()
        
        if await client.is_user_authorized():
            me = await client.get_me()
            print_success(f"Авторизован как: {me.first_name} (@{me.username})")
        else:
            print_warning("Требуется авторизация (войдите через telegram_parser.py)")
        
        await client.disconnect()
        return True
        
    except Exception as e:
        print_error(f"Ошибка: {e}")
        return False

async def test_env():
    """Проверка переменных окружения"""
    print_header("⚙️  ТЕСТ: Переменные окружения")
    
    required = ['TG_API_ID', 'TG_API_HASH']
    optional = ['ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'BOT_TOKEN', 'TARGET_CHANNEL']
    
    all_good = True
    
    print_info("Обязательные переменные:")
    for var in required:
        value = os.getenv(var)
        if value:
            masked = value[:5] + "..." if len(value) > 5 else value
            print_success(f"  {var}: {masked}")
        else:
            print_error(f"  {var}: НЕ УСТАНОВЛЕНА")
            all_good = False
    
    print_info("Опциональные переменные:")
    for var in optional:
        value = os.getenv(var)
        if value:
            masked = value[:10] + "..." if len(value) > 10 else value
            print_success(f"  {var}: {masked}")
        else:
            print_warning(f"  {var}: не установлена")
    
    return all_good

async def main():
    """Главная функция тестирования"""
    print(f"\n{GREEN}{'='*60}{RESET}")
    print(f"{GREEN}  СООБЩИО - КОМПЛЕКСНОЕ ТЕСТИРОВАНИЕ{RESET}")
    print(f"{GREEN}{'='*60}{RESET}")
    print(f"Начало: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    results = {}
    
    # Запуск тестов
    results['env'] = await test_env()
    results['database'] = await test_database()
    results['geo'] = await test_geo_service()
    results['ai'] = await test_ai_service()
    results['api'] = await test_api()
    results['telegram'] = await test_telegram_connection()
    
    # Итоги
    print_header("📊 ИТОГИ ТЕСТИРОВАНИЯ")
    
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    failed = total - passed
    
    print_info(f"Всего тестов: {total}")
    print_success(f"Успешно: {passed}")
    if failed > 0:
        print_error(f"Ошибок: {failed}")
    
    print("\nДетали:")
    for name, result in results.items():
        status = f"{GREEN}✅{RESET}" if result else f"{RED}❌{RESET}"
        print(f"  {status} {name}")
    
    print(f"\n{BLUE}{'='*60}{RESET}")
    if passed == total:
        print(f"{GREEN}🎉 Все тесты пройдены!{RESET}")
    else:
        print(f"{YELLOW}⚠️  Некоторые тесты не пройдены{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    return passed == total

if __name__ == '__main__':
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
