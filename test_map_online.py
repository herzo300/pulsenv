#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Тестирование карты в онлайн режиме
Проверяет: загрузку тайлов, маркирование, определение адреса, Firebase подключение
"""

import asyncio
import logging
import sys
import os
import httpx
import json
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def test_firebase_connection():
    """Проверка подключения к Firebase"""
    logger.info("=" * 60)
    logger.info("ПРОВЕРКА ПОДКЛЮЧЕНИЯ К FIREBASE")
    logger.info("=" * 60)
    
    from core.config import FIREBASE_RTDB_URL
    
    if not FIREBASE_RTDB_URL:
        logger.error("❌ FIREBASE_RTDB_URL не настроен в .env")
        return False
    
    logger.info(f"Firebase URL: {FIREBASE_RTDB_URL}")
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            url = f"{FIREBASE_RTDB_URL}/complaints.json"
            logger.info(f"Запрос к: {url}")
            
            response = await client.get(url)
            logger.info(f"Статус ответа: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data:
                    complaints = list(data.values()) if isinstance(data, dict) else data
                    logger.info(f"✅ Получено жалоб: {len(complaints)}")
                    
                    # Проверяем наличие координат
                    with_coords = [c for c in complaints if c.get('lat') and c.get('lng')]
                    logger.info(f"✅ С координатами: {len(with_coords)}")
                    
                    # Показываем примеры
                    if with_coords:
                        logger.info("\nПримеры жалоб с координатами:")
                        for i, c in enumerate(with_coords[:3], 1):
                            logger.info(f"  {i}. {c.get('category', 'N/A')} - {c.get('address', 'N/A')}")
                            logger.info(f"     Координаты: {c.get('lat')}, {c.get('lng')}")
                    
                    return True
                else:
                    logger.warning("⚠️ Firebase вернул пустые данные")
                    return False
            else:
                logger.error(f"❌ Ошибка подключения: {response.status_code}")
                logger.error(f"Ответ: {response.text[:200]}")
                return False
                
    except Exception as e:
        logger.error(f"❌ Ошибка подключения к Firebase: {e}")
        return False


async def test_geocoding():
    """Проверка определения адреса"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ОПРЕДЕЛЕНИЯ АДРЕСА")
    logger.info("=" * 60)
    
    from services.geo_service import get_coordinates, geoparse
    
    test_addresses = [
        "ул. Ленина 15, Нижневартовск",
        "проспект Победы 20, Нижневартовск",
        "район 10п, Нижневартовск",
    ]
    
    results = []
    
    for address in test_addresses:
        logger.info(f"\nТест адреса: {address}")
        try:
            coords = await get_coordinates(address)
            if coords:
                lat, lng = coords
                logger.info(f"  ✅ Координаты: {lat}, {lng}")
                results.append((address, lat, lng, True))
            else:
                logger.warning(f"  ⚠️ Координаты не найдены")
                results.append((address, None, None, False))
        except Exception as e:
            logger.error(f"  ❌ Ошибка: {e}")
            results.append((address, None, None, False))
    
    # Тест геопарсинга из текста
    logger.info("\nТест геопарсинга из текста:")
    test_texts = [
        "Яма на улице Ленина 15",
        "Проблема на перекрёстке Мира и Победы",
        "Разрушенная дорога в районе 10п",
    ]
    
    for text in test_texts:
        logger.info(f"\nТекст: {text}")
        try:
            geo = await geoparse(text)
            if geo.get('lat') and geo.get('lng'):
                logger.info(f"  ✅ Адрес: {geo.get('address', 'N/A')}")
                logger.info(f"  ✅ Координаты: {geo.get('lat')}, {geo.get('lng')}")
                logger.info(f"  ✅ Источник: {geo.get('geo_source', 'N/A')}")
            else:
                logger.warning(f"  ⚠️ Координаты не найдены")
        except Exception as e:
            logger.error(f"  ❌ Ошибка: {e}")
    
    return len([r for r in results if r[3]]) > 0


async def test_worker_app():
    """Проверка доступности веб-приложения через Worker"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ВЕБ-ПРИЛОЖЕНИЯ (WORKER)")
    logger.info("=" * 60)
    
    from core.config import CF_WORKER
    
    if not CF_WORKER:
        logger.error("❌ CF_WORKER не настроен в .env")
        return False
    
    logger.info(f"Worker URL: {CF_WORKER}")
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            # Проверка /app
            url = f"{CF_WORKER}/app"
            logger.info(f"Проверка: {url}")
            
            response = await client.get(url)
            logger.info(f"Статус: {response.status_code}")
            
            if response.status_code == 200:
                html = response.text
                
                # Проверяем наличие ключевых элементов
                checks = {
                    "Leaflet": "leaflet" in html.lower(),
                    "Map container": 'id="map"' in html or "id='map'" in html,
                    "Firebase config": "CONFIG.firebase" in html or "firebase" in html.lower(),
                    "Marker cluster": "markercluster" in html.lower(),
                    "OpenStreetMap tiles": "openstreetmap" in html.lower() or "tile.openstreetmap" in html.lower(),
                }
                
                logger.info("\nПроверка элементов HTML:")
                all_ok = True
                for check_name, check_result in checks.items():
                    status = "✅" if check_result else "❌"
                    logger.info(f"  {status} {check_name}: {check_result}")
                    if not check_result:
                        all_ok = False
                
                if all_ok:
                    logger.info("\n✅ Все элементы карты найдены в HTML")
                else:
                    logger.warning("\n⚠️ Некоторые элементы не найдены")
                
                return all_ok
            else:
                logger.error(f"❌ Ошибка: {response.status_code}")
                return False
                
    except Exception as e:
        logger.error(f"❌ Ошибка подключения к Worker: {e}")
        return False


async def test_tile_loading():
    """Проверка загрузки тайлов OpenStreetMap"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ЗАГРУЗКИ ТАЙЛОВ")
    logger.info("=" * 60)
    
    # Тестируем загрузку тайла для Нижневартовска (zoom 13, примерно центр города)
    # Нижневартовск: ~60.94, 76.55
    # Для zoom 13: x ~= 5000, y ~= 3000 (примерно)
    
    test_tiles = [
        ("https://tile.openstreetmap.org/13/5000/3000.png", "Нижневартовск (zoom 13)"),
        ("https://tile.openstreetmap.org/12/2500/1500.png", "Нижневартовск (zoom 12)"),
    ]
    
    results = []
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            for tile_url, description in test_tiles:
                logger.info(f"\nТест тайла: {description}")
                logger.info(f"URL: {tile_url}")
                
                try:
                    response = await client.get(tile_url)
                    if response.status_code == 200:
                        content_type = response.headers.get('content-type', '')
                        size = len(response.content)
                        logger.info(f"  ✅ Загружен успешно")
                        logger.info(f"  ✅ Размер: {size} байт")
                        logger.info(f"  ✅ Content-Type: {content_type}")
                        results.append(True)
                    else:
                        logger.warning(f"  ⚠️ Статус: {response.status_code}")
                        results.append(False)
                except Exception as e:
                    logger.error(f"  ❌ Ошибка: {e}")
                    results.append(False)
    except Exception as e:
        logger.error(f"❌ Ошибка подключения: {e}")
        return False
    
    return any(results)


async def test_marker_data():
    """Проверка данных маркеров"""
    logger.info("\n" + "=" * 60)
    logger.info("ПРОВЕРКА ДАННЫХ МАРКЕРОВ")
    logger.info("=" * 60)
    
    from core.config import FIREBASE_RTDB_URL
    
    if not FIREBASE_RTDB_URL:
        logger.error("❌ FIREBASE_RTDB_URL не настроен")
        return False
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            url = f"{FIREBASE_RTDB_URL}/complaints.json"
            response = await client.get(url)
            
            if response.status_code == 200:
                data = response.json()
                if not data:
                    logger.warning("⚠️ Нет данных в Firebase")
                    return False
                
                complaints = list(data.values()) if isinstance(data, dict) else data
                
                # Проверяем структуру данных
                required_fields = ['category', 'lat', 'lng']
                valid_markers = []
                invalid_markers = []
                
                for complaint in complaints:
                    has_all = all(field in complaint and complaint[field] for field in required_fields)
                    if has_all:
                        valid_markers.append(complaint)
                    else:
                        invalid_markers.append(complaint)
                
                logger.info(f"Всего жалоб: {len(complaints)}")
                logger.info(f"✅ Валидных маркеров: {len(valid_markers)}")
                logger.info(f"⚠️ Невалидных маркеров: {len(invalid_markers)}")
                
                if valid_markers:
                    logger.info("\nПримеры валидных маркеров:")
                    for i, m in enumerate(valid_markers[:3], 1):
                        logger.info(f"  {i}. {m.get('category', 'N/A')}")
                        logger.info(f"     Адрес: {m.get('address', 'N/A')}")
                        logger.info(f"     Координаты: {m.get('lat')}, {m.get('lng')}")
                        logger.info(f"     Статус: {m.get('status', 'N/A')}")
                
                if invalid_markers:
                    logger.warning("\nПримеры невалидных маркеров:")
                    for i, m in enumerate(invalid_markers[:3], 1):
                        missing = [f for f in required_fields if not m.get(f)]
                        logger.warning(f"  {i}. Отсутствуют поля: {', '.join(missing)}")
                
                return len(valid_markers) > 0
            else:
                logger.error(f"❌ Ошибка получения данных: {response.status_code}")
                return False
                
    except Exception as e:
        logger.error(f"❌ Ошибка: {e}")
        return False


async def main():
    """Главная функция тестирования"""
    logger.info("=" * 60)
    logger.info("ТЕСТИРОВАНИЕ КАРТЫ В ОНЛАЙН РЕЖИМЕ")
    logger.info("=" * 60)
    logger.info(f"Время: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info("")
    
    results = {}
    
    # 1. Проверка Firebase
    results['firebase'] = await test_firebase_connection()
    
    # 2. Проверка геокодинга
    results['geocoding'] = await test_geocoding()
    
    # 3. Проверка Worker приложения
    results['worker'] = await test_worker_app()
    
    # 4. Проверка загрузки тайлов
    results['tiles'] = await test_tile_loading()
    
    # 5. Проверка данных маркеров
    results['markers'] = await test_marker_data()
    
    # Итоговый отчет
    logger.info("\n" + "=" * 60)
    logger.info("ИТОГОВЫЙ ОТЧЕТ")
    logger.info("=" * 60)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        logger.info(f"{status} {test_name}")
    
    all_passed = all(results.values())
    
    if all_passed:
        logger.info("\n✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ")
        logger.info("\n💡 Рекомендации:")
        logger.info("   1. Откройте карту в Telegram боте через команду /map или кнопку 'Карта'")
        logger.info("   2. Проверьте что тайлы загружаются (должна быть видна карта)")
        logger.info("   3. Проверьте что маркеры отображаются на карте")
        logger.info("   4. Проверьте что при клике на маркер открывается popup с информацией")
        logger.info("   5. Проверьте real-time обновления (новые маркеры должны появляться автоматически)")
    else:
        logger.warning("\n⚠️ НЕКОТОРЫЕ ТЕСТЫ НЕ ПРОЙДЕНЫ")
        logger.warning("\n💡 Рекомендации:")
        failed = [name for name, result in results.items() if not result]
        logger.warning(f"   Проверьте следующие компоненты: {', '.join(failed)}")
    
    return 0 if all_passed else 1


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
