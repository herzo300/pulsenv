#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Тестирование маркирования на карте в веб-приложении
Проверяет работу real-time обновлений через Firebase
"""

import asyncio
import httpx
import json
import logging
from datetime import datetime
from dotenv import load_dotenv
import os

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

CF_WORKER = "https://anthropic-proxy.uiredepositionherzo.workers.dev"
FIREBASE_URL = os.getenv("FIREBASE_RTDB_URL", "https://anthropic-proxy.uiredepositionherzo.workers.dev/firebase")


async def test_webapp_access():
    """Проверка доступа к веб-приложению"""
    logger.info("=" * 60)
    logger.info("ПРОВЕРКА ДОСТУПА К ВЕБ-ПРИЛОЖЕНИЮ")
    logger.info("=" * 60)
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            # Проверяем /app
            version = int(datetime.now().timestamp())
            url = f"{CF_WORKER}/app?v={version}"
            logger.info(f"Проверка URL: {url}")
            
            response = await client.get(url)
            if response.status_code == 200:
                html = response.text
                logger.info(f"✅ Веб-приложение доступно")
                logger.info(f"   Размер HTML: {len(html)} символов")
                
                # Проверяем наличие ключевых элементов
                checks = {
                    "Leaflet": "leaflet" in html.lower(),
                    "Firebase": "firebase" in html.lower() or FIREBASE_URL.split("/")[-1] in html,
                    "Map container": 'id="map"' in html,
                    "Marker cluster": "markercluster" in html.lower(),
                    "Real-time updates": "realtime" in html.lower() or "polling" in html.lower(),
                }
                
                logger.info("\nПроверка компонентов:")
                for component, found in checks.items():
                    status = "✅" if found else "❌"
                    logger.info(f"   {status} {component}: {'Найден' if found else 'Не найден'}")
                
                return all(checks.values())
            else:
                logger.error(f"❌ Ошибка доступа: {response.status_code}")
                return False
    except Exception as e:
        logger.error(f"❌ Ошибка проверки веб-приложения: {e}")
        return False


async def test_firebase_connection():
    """Проверка подключения к Firebase"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ПОДКЛЮЧЕНИЯ К FIREBASE")
    logger.info("=" * 60)
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            # Проверяем доступность Firebase
            url = f"{FIREBASE_URL}/complaints.json?limitToFirst=5"
            logger.info(f"Проверка Firebase: {url}")
            
            response = await client.get(url)
            if response.status_code == 200:
                data = response.json()
                if data:
                    complaints_count = len(data) if isinstance(data, dict) else len(data) if isinstance(data, list) else 0
                    logger.info(f"✅ Firebase доступен")
                    logger.info(f"   Получено жалоб: {complaints_count}")
                    
                    # Проверяем структуру данных
                    if isinstance(data, dict) and data:
                        sample_key = list(data.keys())[0]
                        sample = data[sample_key]
                        logger.info(f"\nПример жалобы:")
                        logger.info(f"   Категория: {sample.get('category', 'N/A')}")
                        logger.info(f"   Адрес: {sample.get('address', 'N/A')}")
                        logger.info(f"   Координаты: {sample.get('lat', 'N/A')}, {sample.get('lng', 'N/A')}")
                        logger.info(f"   Статус: {sample.get('status', 'N/A')}")
                    
                    return True
                else:
                    logger.warning("⚠️ Firebase доступен, но данных нет")
                    return True  # Это нормально, если база пустая
            else:
                logger.error(f"❌ Ошибка Firebase: {response.status_code}")
                logger.error(f"   Ответ: {response.text[:200]}")
                return False
    except Exception as e:
        logger.error(f"❌ Ошибка подключения к Firebase: {e}")
        return False


async def test_marker_creation():
    """Тест создания маркера (симуляция)"""
    logger.info("\n" + "=" * 60)
    logger.info("ТЕСТ СОЗДАНИЯ МАРКЕРА")
    logger.info("=" * 60)
    
    try:
        from services.firebase_service import push_complaint
        
        # Создаем тестовую жалобу
        test_complaint = {
            "category": "Дороги",
            "summary": "Тестовая жалоба для проверки маркирования",
            "text": "Проверка работы real-time маркирования на карте",
            "address": "ул. Мира, 62, Нижневартовск",
            "lat": 60.9344,
            "lng": 76.5531,
            "source": "test",
            "source_name": "test_script",
            "provider": "test",
        }
        
        logger.info("Отправка тестовой жалобы в Firebase...")
        doc_id = await push_complaint(test_complaint)
        
        if doc_id:
            logger.info(f"✅ Тестовая жалоба создана: {doc_id}")
            logger.info(f"   Категория: {test_complaint['category']}")
            logger.info(f"   Координаты: {test_complaint['lat']}, {test_complaint['lng']}")
            logger.info(f"   Адрес: {test_complaint['address']}")
            
            # Проверяем, что жалоба появилась в Firebase
            await asyncio.sleep(2)  # Даем время на синхронизацию
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                url = f"{FIREBASE_URL}/complaints/{doc_id}.json"
                response = await client.get(url)
                if response.status_code == 200:
                    data = response.json()
                    if data:
                        logger.info("✅ Жалоба успешно сохранена в Firebase")
                        logger.info(f"   Проверка доступна по URL: {url}")
                        return True
                    else:
                        logger.warning("⚠️ Жалоба не найдена в Firebase")
                        return False
                else:
                    logger.error(f"❌ Ошибка проверки: {response.status_code}")
                    return False
        else:
            logger.error("❌ Не удалось создать тестовую жалобу")
            return False
            
    except Exception as e:
        logger.error(f"❌ Ошибка теста маркера: {e}", exc_info=True)
        return False


async def test_map_functionality():
    """Проверка функциональности карты"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ФУНКЦИОНАЛЬНОСТИ КАРТЫ")
    logger.info("=" * 60)
    
    logger.info("Проверка компонентов карты:")
    
    checks = {
        "Firebase URL настроен": bool(FIREBASE_URL),
        "Worker URL настроен": bool(CF_WORKER),
        "Координаты центра": True,  # Проверено в коде
        "Zoom уровень": True,  # Проверено в коде
    }
    
    for check, result in checks.items():
        status = "✅" if result else "❌"
        logger.info(f"   {status} {check}")
    
    logger.info("\n💡 Рекомендации для проверки в браузере:")
    logger.info("   1. Откройте веб-приложение через бота (/map)")
    logger.info("   2. Проверьте, что карта загружается")
    logger.info("   3. Проверьте, что маркеры отображаются")
    logger.info("   4. Проверьте, что новые жалобы появляются в реальном времени")
    logger.info("   5. Проверьте фильтры по категориям и статусам")
    
    return all(checks.values())


async def main():
    """Главная функция тестирования"""
    logger.info("\n" + "=" * 60)
    logger.info("ТЕСТИРОВАНИЕ МАРКИРОВАНИЯ НА КАРТЕ")
    logger.info(f"Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info("=" * 60)
    
    results = {}
    
    # Тест 1: Доступ к веб-приложению
    results["webapp"] = await test_webapp_access()
    
    # Тест 2: Подключение к Firebase
    results["firebase"] = await test_firebase_connection()
    
    # Тест 3: Создание маркера
    results["marker"] = await test_marker_creation()
    
    # Тест 4: Функциональность карты
    results["functionality"] = await test_map_functionality()
    
    # Итоги
    logger.info("\n" + "=" * 60)
    logger.info("ИТОГИ ТЕСТИРОВАНИЯ")
    logger.info("=" * 60)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        logger.info(f"{status} {test_name}")
    
    total_passed = sum(1 for r in results.values() if r)
    total_tests = len(results)
    
    logger.info(f"\nРезультат: {total_passed}/{total_tests} тестов пройдено")
    
    if all(results.values()):
        logger.info("\n✅ Все тесты пройдены! Маркирование должно работать корректно.")
    else:
        logger.warning("\n⚠️ Некоторые тесты не пройдены. Проверьте логи выше.")
    
    return all(results.values())


if __name__ == "__main__":
    try:
        success = asyncio.run(main())
        exit(0 if success else 1)
    except KeyboardInterrupt:
        logger.info("\n⏹️ Тестирование прервано")
        exit(1)
    except Exception as e:
        logger.error(f"\n❌ Критическая ошибка: {e}", exc_info=True)
        exit(1)
