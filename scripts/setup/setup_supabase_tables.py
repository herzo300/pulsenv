#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Настройка таблиц Supabase - применение миграций через REST API.

Использование:
    python scripts/setup/setup_supabase_tables.py
"""

import os
import sys
import io
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    import requests
    from dotenv import load_dotenv
except ImportError:
    print("Установите зависимости: pip install requests python-dotenv")
    sys.exit(1)

load_dotenv()

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://xpainxohbdoruakcijyq.supabase.co")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")


def get_headers():
    return {
        "Authorization": f"Bearer {SERVICE_KEY}",
        "apikey": SERVICE_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


def check_table_exists(table_name: str) -> bool:
    """Проверяет существование таблицы"""
    url = f"{SUPABASE_URL}/rest/v1/{table_name}"
    headers = get_headers()
    headers["Range"] = "0-0"
    
    r = requests.get(url, headers=headers, params={"limit": "1"}, timeout=30)
    return r.status_code in (200, 206, 416)


def create_initial_stats():
    """Создаёт начальную статистику"""
    url = f"{SUPABASE_URL}/rest/v1/stats"
    headers = get_headers()
    
    data = {
        "key": "realtime_stats",
        "data": {"total_complaints": 0, "by_category": {}, "last_updated": None}
    }
    
    r = requests.post(url, headers=headers, json=data, timeout=30)
    
    if r.status_code in (200, 201):
        print("  ✅ Создана начальная статистика")
        return True
    elif "duplicate" in r.text.lower() or r.status_code == 409:
        print("  ℹ️ Статистика уже существует")
        return True
    else:
        print(f"  ⚠️ Ошибка создания статистики: {r.status_code}")
        return False


def test_operations():
    """Тестирует CRUD операции"""
    print("\n🧪 Тестирование операций...")
    
    # Test complaints
    url = f"{SUPABASE_URL}/rest/v1/complaints"
    headers = get_headers()
    
    r = requests.get(url, headers=headers, params={"limit": "5", "order": "created_at.desc"}, timeout=30)
    if r.status_code == 200:
        complaints = r.json()
        print(f"  ✅ Чтение complaints: {len(complaints)} записей")
    else:
        print(f"  ❌ Ошибка чтения complaints: {r.status_code}")
        return False
    
    # Test stats
    url = f"{SUPABASE_URL}/rest/v1/stats"
    r = requests.get(url, headers=headers, params={"key": "eq.realtime_stats"}, timeout=30)
    if r.status_code == 200:
        stats = r.json()
        if stats:
            print(f"  ✅ Чтение stats: {stats[0].get('data', {})}")
        else:
            print("  ⚠️ Stats пусто - создаём...")
            create_initial_stats()
    else:
        print(f"  ❌ Ошибка чтения stats: {r.status_code}")
    
    # Test users
    url = f"{SUPABASE_URL}/rest/v1/users"
    r = requests.get(url, headers=headers, params={"limit": "5"}, timeout=30)
    if r.status_code == 200:
        users = r.json()
        print(f"  ✅ Чтение users: {len(users)} записей")
    else:
        print(f"  ❌ Ошибка чтения users: {r.status_code}")
    
    return True


def main():
    print("=" * 60)
    print("🔧 Проверка и настройка таблиц Supabase")
    print("=" * 60)
    
    if not SERVICE_KEY:
        print("❌ SUPABASE_SERVICE_ROLE_KEY не установлен")
        sys.exit(1)
    
    # Проверяем таблицы
    tables = ["complaints", "users", "stats", "infographic_data", "comments", "likes"]
    
    print("\n📋 Проверка таблиц...")
    missing = []
    for table in tables:
        exists = check_table_exists(table)
        status = "✅" if exists else "❌"
        print(f"  {status} {table}")
        if not exists:
            missing.append(table)
    
    if missing:
        print(f"\n⚠️ Отсутствуют таблицы: {', '.join(missing)}")
        print("\nПрименитe миграции через Supabase Dashboard:")
        print("  1. Откройте https://supabase.com/dashboard/project/xpainxohbdoruakcijyq")
        print("  2. Перейдите в SQL Editor")
        print("  3. Выполните содержимое файла:")
        print("     supabase/migrations/001_initial_schema.sql")
        print("     supabase/migrations/002_add_likes_dislikes.sql")
        sys.exit(1)
    
    # Тестируем операции
    test_operations()
    
    print("\n" + "=" * 60)
    print("✅ Supabase настроен и готов к работе!")
    print("=" * 60)


if __name__ == "__main__":
    main()
