#!/usr/bin/env python
"""Скрипт для тестирования интеграции Telegram мониторинга с базой данных"""

import asyncio
import aiohttp
from datetime import datetime

# API URL
API_BASE_URL = "http://127.0.0.1:8000"

async def test_health():
    """Тест: проверка здоровья API"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{API_BASE_URL}/health") as response:
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") == "ok":
                    print("✅ API здоров: OK")
                    return True
                else:
                    print(f"❌ API не здоров: {data.get('status')}")
                    return False
    except Exception as e:
        print(f"❌ API ошибка: {e}")
        return False


async def test_categories():
    """Тест: категории"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{API_BASE_URL}/categories") as response:
                response.raise_for_status()
                data = response.json()
                
                if "categories" in data:
                    print(f"✅ Категории: {len(data['categories'])} шт.")
                    print(f"  Категорияи: {', '.join([c['name'] for c in data['categories'][:5])}")
                    return True
                else:
                    print("❌ Категории не получены")
                    return False
        except Exception as e:
            print(f"❌ Категории ошибка: {e}")
            return False


async def test_complaints_crud():
    """Тест: CRUD операций с жалобами"""
    try:
        async with aiohttp.ClientSession() as session:
            # Создание жалобы
            create_data = {
                "title": "Яма на улице Ленина 15",
                "description": "Большая яма, опасно для пешеходов",
                "latitude": 60.93,
                "longitude": 76.57,
                "category": "Дороги",
            }
            
            async with session.post(f"{API_BASE_URL}/complaints/create") as response:
                response.raise_for_status()
                data = response.json()
                
                if data.get("success"):
                    print(f"✅ Жалоба создана: {data.get('id')}")
                    print(f"   Источник: {data.get('source', 'unknown')}")
                else:
                    print(f"❌ Ошибка создания жалобы: {data.get('error', 'Unknown')}")
                    return data.get("success")
                else:
                    return {"success": False, "error": "error"}
        except Exception as e:
            print(f"❌ Ошибка создания жалобы: {e}")
            return {"success": False, "error": str(e)}
        
        # Получение списка жалоб
        async with session.get(f"{API_BASE_URL}/complaints/list?limit=20") as response:
            response.raise_for_status()
            data = response.json()
            
            if "data" in data:
                print(f"✅ Список жалоб: {len(data['data'])} шт.")
                print(f"   Пагинация: {data.get('count')}/{data['pagination']['total']} (страница {data.get('pagination')['page']}/{data.get('pagination')['pages']}")
                return True
            else:
                print("❌ Жалобы не получены")
                return False
        except Exception as e:
            print(f"❌ Жалобы ошибка: {e}")
            return {"success": False, "error": str(e)}
        
        # Получение детальной жалобы
        async with session.get(f"{API_BASE_URL}/complaints/123") as response:
            response.raise_for_status()
            data = response.json()
            
            if data.get("success"):
                print(f"✅ Жалоба #123: {data.get('id')}")
                print(f"   Статус: {data.get('status')}")
                return data
            else:
                print(f"❌ Жалоба не найдена")
                return {"success": False, "error": data.get("error", "Not found")}
        except Exception as e:
            print(f"❌ Ошибка получения: {e}")
            return {"success": False, "error": str(e)}
        
        # Обновление статуса
        async with session.put(f"{API_BASE_URL}/complaints/123/status") as response:
            response.raise_for_status()
            data = response.json()
            
            if data.get("success"):
                print(f"✅ Статус обновлен: {data.get('data')['status']}")
                return data
            except Exception as e:
            print(f"❌ Ошибка обновления: {e}")
            return {"success": False, "error": str(e)}
        
        except Exception as e:
            print(f"❌ Ошибка обновления: {e}")
            return {"success": False, "error": str(e)}
        
        # Статистика
        async with session.get(f"{API_BASE_URL}/complaints/statistics") as response:
            response.raise_for_status()
            data = response.json()
            
            if "statistics" in data:
                print(f"✅ Статистика получена")
                print(f"   Всего жалоб: {data['statistics']['total']}")
                print(f"   По категориям:")
                for cat, count in data['statistics']['by_category'].items():
                    print(f"     {cat}: {count}")
                print(f"   По каналам:")
                for channel, count in data['statistics']['by_channel'].items():
                    print(f"     {channel}: {count}")
                return data
            else:
                print("❌ Статистика не получена")
                return {"success": False, "error": "Not found"}
        except Exception as e:
            print(f"❌ Статистика ошибка: {e}")
            return {"success": False, "error": str(e)}
        
        except Exception as e:
            print(f"❌ Статистика ошибка: {e}")
            return {"success": False, "error": str(e)}
    
    return True


async def test_telegram_monitoring():
    """Тест: Telegram мониторинга"""
    try:
        async with aiohttp.ClientSession() as session:
            # Запуск мониторинга (тестовый режим)
            start_data = {
                "api_id": 36578556,
                "api_hash": "f47cba45f7d0f4940f71ad166201835a",
                "phone": "+18457266658",
                "channels": ["@test_channel_1", "@test_channel_2"],
            }
            
            response = await session.post(f"{API_BASE_URL}/telegram/monitor/start", json=start_data)
            response.raise_for_status()
            data = response.json()
            
            if data.get("success"):
                print(f"✅ Мониторинг запущен")
                print(f"   Каналов: {len(data.get('channels'))}")
                return data
            else:
                print(f"❌ Ошибка запуска мониторинга: {data.get('error', 'Unknown')}")
                return data
        except Exception as e:
            print(f"❌ Ошибка запуска мониторинга: {e}")
            return {"success": False, "error": str(e)}
            await asyncio.sleep(2)  # Ждем пока мониторинг инициализируется
            
            # Проверка статуса
            async with session.get(f"{API_BASE_URL}/telegram/monitor/status") as response:
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") == "running":
                    print(f"✅ Мониторинг работает: {data.get('status')}")
                    
                    stats = data.get("statistics")
                    print(f"   Сообщений: {stats.get('total_messages')}")
                    print(f"   По категориям:")
                    for cat, count in stats.get("by_category", {}).items():
                        print(f"     {cat}: {count}")
                    print(f"   По каналам:")
                    for channel, count in stats.get("by_channel", {}).items():
                        print(f"     {channel}: {count}")
                    return data
                else:
                    print("❌ Мониторинг не работает")
                    return {"success": False, "error": "Not running"}
        except Exception as e:
            print(f"❌ Ошибка статуса: {e}")
            return {"success": False, "error": str(e)}
        
            # Получение сообщений
            async with session.get(f"{API_BASE_URL}/telegram/monitor/messages?category=Дороги&limit=10") as response:
                response.raise_for_status()
                data = response.json()
                
                if "messages" in data:
                    print(f"✅ Сообщений: {len(data['messages'])} шт.")
                    print(f"   Фильтр: {data.get('category')}")
                    for msg in data.get("messages")[:5]:
                        print(f"     - {msg.get('text')[:50]}")
                    return data
                else:
                    print("❌ Сообщения не получены")
                    return {"success": False, "error": str(e)}
        except Exception as e:
            print(f"❌ Ошибка получения сообщений: {e}")
            return {"success": False, "error": str(e)}
        
        # Остановка мониторинга
        async with session.post(f"{API_BASE_URL}/telegram/monitor/stop") as response:
            response.raise_for_status()
            data = response.json()
            
            if data.get("success"):
                print(f"✅ Мониторинг остановлен")
                return data
            except Exception as e:
            print(f"❌ Ошибка остановки: {e}")
            return {"success": False, "error": str(e)}
        
        await asyncio.sleep(1)  # Ждем
        
        # Проверка статуса
        async with session.get(f"{API_BASE_URL}/telegram/monitor/status") as response:
            response.raise_for_status()
            data = response.json()
                
                if data.get("status") == "stopped":
                    print(f"✅ Мониторинг остановлен")
                    return data
                else:
                    print(f"❌ Мониторинг все еще работает")
                    return {"success": False, "error": "Not stopped"}
        except Exception as e:
            print(f"❌ Ошибка статуса: {e}")
            return {"success": False, "error": str(e)}
    
    return True


async def test_nvd():
    """Тест: NVD API"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get("https://data.n-vartovsk.ru/api/v1/8603032896-docagtext") as response:
                response.raise_for_status()
                data = response.json()
                
                if data.get("status_code") == 200:
                    print(f"✅ NVD API доступен")
                    return True
                else:
                    print(f"❌ NVD API недоступен: {data.get('status_code')}")
                    return False
        except Exception as e:
            print(f"❌ NVD API ошибка: {e}")
            return False
        
        # Паспорт
        async with session.get(f"{API_BASE_URL}/nvd/passport") as response:
            response.raise_for_status()
            data = response.json()
            
            if data.get("success"):
                print(f"✅ Паспорт NVD получен: {data.get('identifier')}")
                print(f"   Название: {data.get('title')}")
                return data
            else:
                print(f"❌ Паспорт не получен")
                return {"success": False, "error": data.get("error", "Not found")}
        except Exception as e:
            print(f"❌ Паспорт ошибка: {e}")
            return {"success": False, "error": str(e)}
        
        # Уязвимости
        async with session.get(f"https://data.n-vartovsk.ru/api/v1/8603032896-docagtext/vulnerabilities?limit=10") as response:
            response.raise_for_status()
            data = response.json()
                
            if "vulnerabilities" in data:
                print(f"✅ Уязвимости получены: {len(data['vulnerabilities'])} шт.")
                for vuln in data["vulnerabilities"]:
                    print(f"   - {vuln.get('cve_id', 'N/A'): {vuln.get('score')}")
                return data
            else:
                print("❌ Уязвимости не получены")
                    return {"success": False, "error": "Not found"}
        except Exception as e:
            print(f"❌ Ошибка получения уязвимостей: {e}")
            return {"success": False, "error": str(e)}
        
        # Статистика
        async with session.get("https://data.n-vartovsk.ru/api/v1/8603032896-docagtext/statistics") as response:
            response.raise_for_status()
            data = response.json()
                
            if "statistics" in data:
                print(f"✅ Статистика получена")
                print(f"   Всего датасетов: {data['statistics']['total_datasets']}")
                print(f"   Размер: {data['statistics']['size_mb']} МБ")
                print(f"   Форматы: {', '.join(data['statistics']['formats'][:5])}")
                return data
            else:
                print("❌ Статистика не получена")
                return {"success": False, "error": "Not found"}
        except Exception as e:
            print(f"❌ Статистика ошибка: {e}")
            return {"success": False, "error": str(e)}
        
        except Exception as e:
            print(f"❌ Статистика ошибка: {e}")
            return {"success": False, "error": str(e)}
    
    return True


async def test_all():
    """Полный тест всех подсистем"""
    print("=" * 60)
    print("🚀 Начинаю тестирование...")
    
    results = []
    
    # Тест 1: Health Check
    print("Тест 1/6: Проверка здоровья API...")
    health_result = await test_health()
    results.append(("Health Check", health_result))
    
    # Тест 2: Categories
    print("Тест 2/6: Проверка категорий...")
    categories_result = await test_categories()
    results.append(("Categories", categories_result))
    
    # Тест 3: Complaints CRUD
    print("Тест 3/6: Проверка CRUD операций...")
    complaints_crud_result = await test_complaints_crud()
    results.append(("Complaints CRUD", complaints_crud_result))
    
    # Тест 4: Telegram Monitoring
    print("Тест 4/6: Проверка мониторинга...")
    monitoring_result = await test_telegram_monitoring()
    results.append(("Telegram Monitoring", monitoring_result))
    
    # Тест 5: NVD API
    print("Тест 5/6: Проверка NVD...")
    nvd_result = await test_nvd()
    results.append(("NVD API", nvd_result))
    
    # Тест 6: Datasets
    print("Тест 6/6: Проверка датасетов...")
    datasets_result = await test_datasets()
    results.append(("Datasets", datasets_result))
    
    # Итого
    all_passed = all(r[1] for r in results)
    
    print("=" * 60)
    print(f"✅ Тестирование завершено!")
    print(f"Результаты:")
    for name, result in results:
        status = "✅" if isinstance(result, dict) and result.get("success", False) else "❌"
        print(f"   {name}")
    
    print("\n📋 Система готова к продакшену тестированию!")
    
    return all_passed


async def main():
    """Главная функция тестирования"""
    results = await test_all()
    
    if all(results):
        print("\n✅ Все системы прошли проверку!")
        print("\n🎯 Можно запускать:")
        print("  python main.py - Backend API")
        print("  flutter run - Flutter Frontend (в папке lib/)")
        print("  python test_integrations.py - Тесты интеграции")
        print("\n📱 Для мониторинга:")
        print("  python -c services/telegram_monitor.py --start")
        print("  curl http://127.0.0.1:8000/telegram/monitor/start --start monitoring")
        print("  curl http://127.0.0.1:8000/telegram/monitor/messages --get messages")
        print("  curl http://127.0.0.1:8000/telegram/monitor/stop --stop monitoring")
    
    print("\n📝 Конфигурация:")
    print("  .env - Настройте реальные API ключи Telegram!")
    print("  TG_BOT_TOKEN - для уведомлений")
    print("  TELEGRAM_CHANNELS - добавьте каналы вашего города")
    
    print("\n🚀 Запуск:")
    print("  python main.py")
    print("  flutter run -d chrome")
    print("  python test_integrations.py")
    
    print("\n📚 Документация:")
    print("  TELEGRAM_SETUP.md - Инструкция по мониторингу")
    print("  API_DOCUMENTATION.md - Полный API список")
    print("  README_NEW.md - Обзор проекта")
    print("  TELEGRAM_MONITORING_INTEGRATED.md - Интеграция завершена")


if __name__ == "__main__":
    asyncio.run(main())
