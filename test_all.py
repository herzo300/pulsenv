#!/usr/bin/env python3
"""
Скрипт для тестирования всей системы СообщиО

import asyncio
import aiohttp
import sys
from datetime import datetime

API_BASE = "http://127.0.0.1:8000"

# Цвета для вывода
GREEN = "\033[0m"
RED = "\033[31m"
YELLOW = "\033[33m"
BLUE = "\033[32m"

async def print_colored(text, color_code):
    print(f"{color_code}{text}")

async def print_success(text):
    print(f"✅ {text}")

async def print_warning(text):
    print(f"⚠ {text}")

def print_header(text):
    print(f"\n{'='='} {text}")
    print("=" * 60)


# ============================================================================
# 1. Тестирование Backend API
print_header("ТЕСТИРОВАНИЕ BACKEND API")
print("=" * 60)

print_success("Проверяем работоспособность...")

async def test_backend():
    """Тестирование Backend API"""
    print_header("Проверяем работоспособность...")
    
    errors = []
    
    try:
        # Тест 1: Health Check
        print_header("Тест 1: Health Check...")
        async with aiohttp.ClientSession() as session:
            try:
                response = await session.get(f"{API_BASE}/health")
                response.raise_for_status()
                
                data = response.json()
                print_success(f"Health check: {data.get('status')}")
                
            except Exception as e:
                print_error(f"Health check failed: {str(e)}")
                errors.append("Health check failed")
            success = False
                data = None
        
        # Тест 2: Categories Endpoint
        print_header("Тест 2: Categories Endpoint...")
        async with aiohttp.ClientSession() as session:
            try:
                response = await session.get(f"{API_BASE}/categories")
                response.raise_for_status()
                
                data = response.json()
                print_success(f"Categories check: {len(data['categories'])} категори")
                
                if len(data.get("categories")) == 10:
                    print_success("Categories check: 10 категорий")
                else:
                    print_warning("Categories check:  категорий != 10")
            except Exception as e:
                print_error(f"Categories check failed: {str(e)}")
                errors.append("Categories check failed")
                success = False
                data = None
        
        # Тест 3: Complaint Creation Endpoint
        print_header("Тест 3: Complaints Creation...")
        
        test_complaints = []
        
        # Тест жалобы для создания
        titles = ["Яма на Ленина 15", "Нет света Омская 45", "Мусор у ТЦ Ладуга"]
        descriptions = ["Большая яма, опасно для пешеходов", "Светофор сломан", "Фонарь не работает"]
        categories = ["Дороги", "ЖКХ", "Транспорт", "Зеленые зоны"]
        sources = ["telegram_monitoring", "mobile_app"]
        
        for i, (title, description, category, source) in zip(titles, descriptions, categories, sources):
            try:
                # Симулируем отправку
                async with aiohttp.ClientSession() as session:
                    response = await session.post(
                        f"{API_BASE}/complaints",
                        json={
                            "title": title,
                            "description": description,
                            "latitude": 60.93,
                            "longitude": 76.57,
                            "category": category,
                            "status": "open",
                            "source": source,
                        },
                        headers={"Content-Type": "application/json"}
                    )
                    response.raise_for_status()
                
                if response.status_code == 201:
                    complaint_id = response.data.get("id")
                    print_success(f"Жалоба {i}: {title} создан")
                    
                    errors.append(f"Жалоба {i} не найдена: {complaint_id} - No data")
                    data = None
                    success = False
                except Exception as e:
                    print_error(f"Жалоба {i} не найдена: {complaint_id}: {str(e)}")
                    errors.append(f"Жалоба {i} ошибка создания: {str(e)}")
                    success = False
                    data = None
            else:
                    print_error(f"Жалоба {i}: status code = {response.status_code}")
                    success = False
                    data = None
        
            # Фиксируем ид жалобы
            test_complaints.append(complaint_id)
            
            # Тест 4: Statistics
        print_header("Тест 4: Statistics Check...")
        
        try:
            async with aiohttp.ClientSession() as session:
                response = await session.get(f"{API_BASE}/complaints/statistics")
                response.raise_for_status()
                
                data = response.json()
                
                print_success(f"Statistics: {data.get('total')}")
                print_warning(f"Всего жалоб: {data.get('total')}")
                if data.get("total") > 0:
                    print_success(f"Statistics check: {data.get('total')} жалоб")
                else:
                    print_warning(f"Statistics check: нет жалоб")
                success = False
            except Exception as e:
                print_error(f"Statistics check failed: {str(e)}")
                errors.append("Statistics check failed")
                success = False
                data = None
        
        # Тест 5: Reports List
        print_header("Тест 5: Reports List...")
        
        try:
            async with aiohttp.ClientSession() as session:
                response = await session.get(f"{API_BASE}/complaints?limit=10")
                response.raise_for_status()
                
                data = response.json()
                
                if response.status_code == 200:
                    complaints = data.get("data", [])
                    print_success(f"Reports list: {len(complaints)} жалоб")
                    
                    if len(complaints) == 10:
                        print_success("Reports list: 10 жалоб")
                    else:
                        print_warning(f"Reports list: {len(complaints)} жалоб (не 10)")
                    success = False
                data = None
            except Exception as e:
                print_error(f"Reports list failed: {str(e)}")
                errors.append("Reports list failed")
                success = False
                data = None
        
        # Тест 6: Telegram Monitoring
        print_header("Тест 6: Telegram Monitoring Check...")
        
        try:
            async with aiohttp.ClientSession() as session:
                response = await session.get(f"{API_BASE}/telegram/monitor/status")
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") == "running":
                    print_success(f"Telegram monitor: работает")
                else:
                    print_warning(f"Telegram monitor: не запущен")
                    success = False
                    data = None
            except Exception as e:
                print_error(f"Telegram monitor failed: {str(e)}")
                errors.append("Telegram monitor failed")
                success = False
                data = None
        
        # Тест 7: NVD Integration Check
        print_header("Тест 7: NVD Integration Check...")
        
        try:
            async with aiohttp.ClientSession() as session:
                response = await session.get(f"{API_BASE}/nvd/passport")
                response.raise_for_status()
                
                data = response.json()
                
                if response.status_code == 200:
                    print_success(f"NVD API доступен")
                    success = True
                    data = response.get("identifier")
                print_success(f"NVD API паспорт: {data.get('title')}")
                    print_warning(f"NVD API описание: {data.get('description')}")
                    data = response.get("keywords", [])
                    print_success(f"NVD API keywords: {data.get('keywords')}")
                    data = response.get("fields", [])
                print_success(f"NVD API поля: {data.get('publisher')}")
                    print_success(f"NVD API создана: {data.get('created')}")
                    print_warning(f"NVD API модифицирован: {data.get('modified')}")
                    print_success(f"NVD API обновлена: {data.get('modified')}")
                    print_warning(f"NVD API устаревшее: {data.get('last_updated')}")
                    data = response.get("size_mb")}")
                
                else:
                    print_warning(f"NVD API недоступен")
                    success = False
                    data = None
            except Exception as e:
                print_error(f"NVD API failed: {str(e)}")
                errors.append("NVD API failed")
                success = False
                data = None
                except Exception as e:
                print_error(f"NVD API ошибка: {str(e)}")
                success = False
                data = None
        
        # Тест 8: Datasets Check
        print_header("Тест 8: Datasets Check...")
        
        try:
            async with aiohttp.ClientSession() as session:
                response = await session.get(f"{API_BASE}/datasets/list?limit=50")
                response.raise_for_status()
                
                data = response.json()
                
                if response.status_code == 200:
                    datasets = data.get("datasets", [])
                    print_success(f"Datasets list: {len(datasets)}) датасетов")
                    
                    if len(datasets) > 0:
                        print_success(f"Datasets list: {len(datasets)} датасетов")
                    else:
                        print_warning(f"Datasets list: нет датасетов")
                    success = False
                data = None
            except Exception as e:
                print_error(f"Datasets list failed: {str(e)}")
                errors.append("Datasets list failed")
                success = False
                data = None
        
        # Тест 9: Full Integration Test
        print_header("Тест 9: Full Integration Test...")
        
        try:
            async with aiohttp.ClientSession() as session:
                response = await session.get(f"{API_BASE}/telegram/monitor/start")
                response.raise_for_status()
                
                data = response.json()
                
                if response.status_code == 200:
                    print_success(f"Telegram monitor запущен")
                    
                    # Тестируем мониторинг
                    response = await session.get(f"{API_BASE}/telegram/monitor/messages?limit=50")
                    response.raise_for_status()
                
                data = response.json()
                
                if response.status_code == 200:
                    messages = data.get("messages", [])
                    print_success(f"Telegram messages: {len(messages)} сообщений")
                    
                    if len(messages) == 50:
                        print_success(f"Telegram messages: {len(messages)} сообщений")
                    else:
                        print_warning(f"Telegram messages: {len(messages)} сообщений (не 50)")
                    success = False
                    data = None
                except Exception as e:
                print_error(f"Telegram messages failed: {str(e)}")
                errors.append("Telegram messages failed")
                success = False
                data = None
        
        # Итого
        print("=" * 60)
        print(f"\n")
        print("=" * 60)
        print_success("\n✅ Все тесты завершены!")
        print()
        print(f"\n")
        print("=" * 60)
    
    return errors


async def run_tests():
    """Запуск всех тестов"""
    print(f"\n")
    print("=" * 60)
    print(f"\n🚀 Запуск тестовых...")
    
    results = await test_backend()
    
    print(f"\n")
    print("=" * 60)
    
    success_count = 0
    
    return results


async def test_backend():
    """Тестирование Backend API"""
    print(f"\n")
    print("=" * 60)
    print(f"\n🚀 Запуск backend теста...")
    
    errors = await test_health()
    
    print(f"\n")
    print("=" * 60)
    
    health_errors = []
    
    categories_errors = []
    
    complaints_errors = []
    
    statistics_errors = []
    
    reports_errors = []
    
    telegram_errors = []
    
    nv_errors = []
    
    datasets_errors = []
    
    full_errors = []
    
    success_count = 0
    
    return {
        "test_health": health_errors,
        "test_categories": categories_errors,
        "test_complaints_creation": complaints_errors,
        "test_reports_list": reports_errors,
        "test_telegram_monitoring": telegram_errors,
        "test_nv_api": nv_errors,
        "test_datasets": datasets_errors,
        "test_full_integration": full_errors,
    }


if __name__ == "__main__":
    print_success("\n🚀 Тесты запущены...")
    asyncio.run(run_tests())
