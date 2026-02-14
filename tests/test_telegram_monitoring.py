#!/usr/bin/env python3
"""
Тестовый скрипт для проверки мониторинга Telegram каналов
Запуск: python test_telegram_monitoring.py

Проверяет:
1. Подключение к Telegram API
2. Чтение сообщений из каналов
3. AI анализ сообщений
4. Геопарсинг адресов
5. Автопубликацию в целевой канал
"""

import os
import asyncio
import sys
from datetime import datetime

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.telegram_parser import (
    analyze_complaint,
    CATEGORIES,
    CATEGORY_EMOJI,
    CATEGORY_TAG
)
from services.geo_service import get_coordinates, make_street_view_url
from dotenv import load_dotenv

# Загружаем переменные окружения
load_dotenv()


async def test_ai_analysis():
    """Тест AI анализа сообщений"""
    print("\n" + "="*60)
    print("🧠 ТЕСТ 1: AI Анализ жалоб")
    print("="*60)
    
    test_messages = [
        "На улице Ленина 25 во дворе огромная яма, машины еле проезжают",
        "В парке Мира сломаны все скамейки, дети негде посидеть",
        "На перекрестке Гагарина и Мира не работает светофор, аварийная ситуация",
        "В доме по адресу ул. Победы 10 нет горячей воды уже неделю",
    ]
    
    for i, message in enumerate(test_messages, 1):
        print(f"\n📨 Сообщение {i}: {message[:50]}...")
        
        try:
            result = await analyze_complaint(message)
            print(f"   ✅ Категория: {result.get('category', 'N/A')}")
            print(f"   📍 Адрес: {result.get('address', 'N/A')}")
            print(f"   📝 Резюме: {result.get('summary', 'N/A')}")
        except Exception as e:
            print(f"   ❌ Ошибка: {e}")


async def test_geoparsing():
    """Тест геопарсинга адресов"""
    print("\n" + "="*60)
    print("🗺️ ТЕСТ 2: Геопарсинг адресов")
    print("="*60)
    
    test_addresses = [
        "ул. Ленина, 25",
        "проспект Мира, 10",
        "ул. Гагарина, 5",
        "парк Мира",
        "перекресток Ленина и Гагарина",
    ]
    
    for address in test_addresses:
        print(f"\n📍 Адрес: {address}")
        
        try:
            coords = await get_coordinates(address)
            if coords:
                lat, lon = coords
                street_view = make_street_view_url(lat, lon)
                print(f"   ✅ Координаты: {lat}, {lon}")
                print(f"   🌐 Street View: {street_view}")
            else:
                print(f"   ⚠️ Координаты не найдены")
        except Exception as e:
            print(f"   ❌ Ошибка: {e}")


async def test_categories():
    """Тест категорий и эмодзи"""
    print("\n" + "="*60)
    print("📋 ТЕСТ 3: Категории и эмодзи")
    print("="*60)
    
    print(f"\n📊 Всего категорий: {len(CATEGORIES)}")
    print("\nСписок категорий:")
    
    for cat in CATEGORIES:
        emoji = CATEGORY_EMOJI.get(cat, '❔')
        tag = CATEGORY_TAG.get(cat, 'прочее')
        print(f"   {emoji} {cat} (#{tag})")


async def test_full_pipeline():
    """Тест полного пайплайна"""
    print("\n" + "="*60)
    print("🔄 ТЕСТ 4: Полный пайплайн обработки")
    print("="*60)
    
    test_message = "На улице Ленина 25 огромная яма во дворе, дети могут упасть! Срочно почините!"
    
    print(f"\n📨 Входящее сообщение: {test_message}")
    print("\n🔄 Обработка...")
    
    try:
        # 1. AI анализ
        analysis = await analyze_complaint(test_message)
        category = analysis.get('category', 'Прочее')
        address = analysis.get('address')
        summary = analysis.get('summary', test_message[:100])
        
        print(f"\n✅ AI Анализ:")
        print(f"   Категория: {category}")
        print(f"   Адрес: {address}")
        print(f"   Резюме: {summary}")
        
        # 2. Геопарсинг
        lat, lon = None, None
        street_view_url = None
        
        if address:
            coords = await get_coordinates(address)
            if coords:
                lat, lon = coords
                street_view_url = make_street_view_url(lat, lon)
                print(f"\n✅ Геопарсинг:")
                print(f"   Координаты: {lat}, {lon}")
                print(f"   Street View: {street_view_url}")
        
        # 3. Формирование текста для публикации
        emoji = CATEGORY_EMOJI.get(category, '❔')
        tag = CATEGORY_TAG.get(category, 'прочее')
        
        publish_text = f"""{emoji} [{category}] {summary}
        
📍 Адрес: {address or 'Не указан'}

👁 Street View: {street_view_url or 'Недоступно'}

#{tag} #СообщиО #Нижневартовск"""
        
        print(f"\n✅ Текст для публикации:")
        print("-" * 60)
        print(publish_text)
        print("-" * 60)
        
    except Exception as e:
        print(f"\n❌ Ошибка: {e}")


def check_env():
    """Проверка переменных окружения"""
    print("="*60)
    print("🔧 ПРОВЕРКА ОКРУЖЕНИЯ")
    print("="*60)
    
    required_vars = [
        'TG_API_ID',
        'TG_API_HASH', 
        'ANTHROPIC_API_KEY',
    ]
    
    optional_vars = [
        'TARGET_CHANNEL',
    ]
    
    all_ok = True
    
    print("\nОбязательные переменные:")
    for var in required_vars:
        value = os.getenv(var)
        if value:
            masked = value[:10] + "..." if len(value) > 10 else value
            print(f"   ✅ {var}: {masked}")
        else:
            print(f"   ❌ {var}: НЕ УСТАНОВЛЕНА")
            all_ok = False
    
    print("\nОпциональные переменные:")
    for var in optional_vars:
        value = os.getenv(var)
        if value:
            print(f"   ✅ {var}: {value}")
        else:
            print(f"   ⚠️ {var}: Не установлена (автопубликация отключена)")
    
    return all_ok


async def test_telegram_connection():
    """Тест подключения к Telegram"""
    print("\n" + "="*60)
    print("📱 ТЕСТ 5: Подключение к Telegram")
    print("="*60)
    
    api_id = os.getenv('TG_API_ID')
    api_hash = os.getenv('TG_API_HASH')
    
    if not api_id or not api_hash:
        print("\n❌ TG_API_ID или TG_API_HASH не установлены")
        print("   Получите их на https://my.telegram.org")
        return False
    
    try:
        from telethon import TelegramClient
        
        print("\n🔄 Подключение к Telegram...")
        client = TelegramClient('test_session', int(api_id), api_hash)
        
        await client.connect()
        
        if await client.is_user_authorized():
            me = await client.get_me()
            print(f"\n✅ Успешное подключение!")
            print(f"   Пользователь: {me.first_name} (@{me.username})")
            print(f"   ID: {me.id}")
        else:
            print("\n⚠️ Требуется авторизация")
            print("   Запустите: python services/telegram_parser.py")
            print("   И войдите в свой аккаунт Telegram")
        
        await client.disconnect()
        return True
        
    except Exception as e:
        print(f"\n❌ Ошибка подключения: {e}")
        return False


async def main():
    """Главная функция тестирования"""
    print("\n")
    print("╔" + "="*58 + "╗")
    print("║" + " "*18 + "СООБЩИО - ТЕСТИРОВАНИЕ" + " "*19 + "║")
    print("╚" + "="*58 + "╝")
    print(f"\n🕐 Начало тестирования: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Проверка окружения
    if not check_env():
        print("\n❌ Критические переменные не установлены!")
        print("   Создайте файл .env на основе .env.example")
        return
    
    # Запуск тестов
    try:
        await test_categories()
        await test_ai_analysis()
        await test_geoparsing()
        await test_full_pipeline()
        await test_telegram_connection()
        
        print("\n" + "="*60)
        print("✅ ТЕСТИРОВАНИЕ ЗАВЕРШЕНО")
        print("="*60)
        print(f"\n🕐 Окончание: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
    except Exception as e:
        print(f"\n❌ Критическая ошибка: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    asyncio.run(main())
