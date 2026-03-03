#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Seed Supabase with test complaints data for Nizhnevartovsk.
Загружает тестовые жалобы в Supabase для проверки карты.
"""

import os
import sys
import io
import random
from datetime import datetime, timedelta
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from dotenv import load_dotenv
load_dotenv(project_root / '.env')

# Supabase REST API
import requests

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://xpainxohbdoruakcijyq.supabase.co')
SUPABASE_ANON_KEY = os.getenv('SUPABASE_ANON_API_KEY') or os.getenv('SUPABASE_SERVICE_KEY')

if not SUPABASE_ANON_KEY:
    print("❌ SUPABASE_ANON_API_KEY not found in .env")
    sys.exit(1)

# API endpoint
API_URL = f"{SUPABASE_URL}/rest/v1"

HEADERS = {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

# ═══════════════════════════════════════════════════════════════════════
# TEST DATA: Real addresses and locations in Nizhnevartovsk
# ═══════════════════════════════════════════════════════════════════════

CATEGORIES = [
    'Дороги', 'ЖКХ', 'Благоустройство', 'Транспорт', 'Освещение',
    'Мусор', 'Детские площадки', 'Парковки', 'Безопасность', 'Прочее'
]

STATUSES = ['open', 'in_progress', 'resolved', 'closed']

# Real locations in Nizhnevartovsk with coordinates
LOCATIONS = [
    {"address": "ул. Ленина, 15", "lat": 60.9366, "lng": 76.5594, "district": "Центр"},
    {"address": "ул. Интернациональная, 22", "lat": 60.9391, "lng": 76.5652, "district": "Центр"},
    {"address": "ул. Мира, 48", "lat": 60.9422, "lng": 76.5718, "district": "Центр"},
    {"address": "ул. 60 лет Октября, 64", "lat": 60.9298, "lng": 76.5489, "district": "Юг"},
    {"address": "ул. Чапаева, 31", "lat": 60.9478, "lng": 76.5801, "district": "Север"},
    {"address": "ул. Нефтяников, 88", "lat": 60.9344, "lng": 76.5523, "district": "Центр"},
    {"address": "ул. Дзержинского, 5", "lat": 60.9412, "lng": 76.5678, "district": "Центр"},
    {"address": "ул. Комсомольский бульвар, 10", "lat": 60.9456, "lng": 76.5745, "district": "Север"},
    {"address": "ул. Ханты-Мансийская, 25", "lat": 60.9334, "lng": 76.5612, "district": "Юг"},
    {"address": "ул. Северная, 72", "lat": 60.9501, "lng": 76.5834, "district": "Север"},
    {"address": "микрорайон 7, д. 12", "lat": 60.9378, "lng": 76.5567, "district": "7 мкр"},
    {"address": "микрорайон 10, д. 5", "lat": 60.9445, "lng": 76.5789, "district": "10 мкр"},
    {"address": "ул. Индустриальная, 33", "lat": 60.9289, "lng": 76.5456, "district": "Промзона"},
    {"address": "ул. Маршала Жукова, 19", "lat": 60.9467, "lng": 76.5812, "district": "Север"},
    {"address": "ул. Омская, 8А", "lat": 60.9356, "lng": 76.5534, "district": "Центр"},
    {"address": "ул. Спортивная, 44", "lat": 60.9423, "lng": 76.5701, "district": "Центр"},
    {"address": "ул. Куропаткина, 3", "lat": 60.9389, "lng": 76.5623, "district": "Центр"},
    {"address": "ул. Победы, 27", "lat": 60.9401, "lng": 76.5689, "district": "Центр"},
    {"address": "пр. Победы, 18", "lat": 60.9434, "lng": 76.5756, "district": "Центр"},
    {"address": "ул. Менделеева, 15", "lat": 60.9312, "lng": 76.5501, "district": "Юг"},
]

# Sample complaint templates
COMPLAINT_TEMPLATES = {
    'Дороги': [
        {"summary": "Яма на дороге", "description": "Глубокая яма на проезжей части, опасно для автомобилей. Размер примерно 50x30 см, глубина около 15 см."},
        {"summary": "Разбитый асфальт", "description": "Асфальтовое покрытие в ужасном состоянии. Множество трещин и выбоин на протяжении 100 метров."},
        {"summary": "Не чистят дорогу от снега", "description": "Уже неделю не убирают снег с дороги. Проехать невозможно, машины буксуют."},
    ],
    'ЖКХ': [
        {"summary": "Прорыв трубы", "description": "Из-под земли течёт горячая вода. Пар над дорогой. Опасно для пешеходов."},
        {"summary": "Нет отопления", "description": "Уже 3 дня нет отопления в доме. Температура в квартирах упала до 14 градусов."},
        {"summary": "Подтопление подвала", "description": "В подвале дома стоит вода. Запах сырости и плесени. Нужна срочная откачка."},
    ],
    'Благоустройство': [
        {"summary": "Сломанная скамейка", "description": "В сквере сломана скамейка. Торчат гвозди, опасно для детей и взрослых."},
        {"summary": "Разбитая плитка", "description": "Тротуарная плитка разбита на большом участке. Пешеходы спотыкаются."},
        {"summary": "Заросший газон", "description": "Газон не стригли всё лето. Трава выросла по пояс, разводятся клещи."},
    ],
    'Транспорт': [
        {"summary": "Автобус не ходит по расписанию", "description": "Автобус маршрута №8 систематически не приходит по расписанию. Ожидание по 40 минут."},
        {"summary": "Нет остановочного павильона", "description": "На остановке нет павильона. Люди мёрзнут зимой в ожидании транспорта."},
    ],
    'Освещение': [
        {"summary": "Не горит фонарь", "description": "Уличный фонарь не работает уже месяц. Темно и опасно по вечерам."},
        {"summary": "Мигающий свет", "description": "Фонарь постоянно мигает, создаёт дискомфорт и может спровоцировать эпилептический приступ."},
    ],
    'Мусор': [
        {"summary": "Переполнены мусорные контейнеры", "description": "Контейнеры переполнены, мусор лежит вокруг. Антисанитария, запах."},
        {"summary": "Несанкционированная свалка", "description": "Образовалась стихийная свалка во дворе. Строительный мусор, старая мебель."},
    ],
    'Детские площадки': [
        {"summary": "Сломанные качели", "description": "На детской площадке сломаны качели. Крепление ненадёжное, опасно для детей."},
        {"summary": "Нет песка в песочнице", "description": "Песочница пустая, дети играют на земле. Нужно засыпать чистый песок."},
    ],
    'Парковки': [
        {"summary": "Нет разметки парковки", "description": "Отсутствует разметка парковочных мест. Машины паркуются хаотично."},
        {"summary": "Автомобиль на газоне", "description": "Регулярно паркуют машины на газоне. Трава уничтожена, грязь."},
    ],
    'Безопасность': [
        {"summary": "Опасный переход", "description": "На пешеходном переходе нет светофора и зебры. Очень опасно переходить дорогу."},
        {"summary": "Открытый люк", "description": "Канализационный люк без крышки. Опасно для пешеходов, особенно ночью."},
    ],
    'Прочее': [
        {"summary": "Бродячие собаки", "description": "Стая бродячих собак во дворе. Пугают детей и взрослых, были случаи нападения."},
        {"summary": "Шум от стройки", "description": "Строительные работы ведутся круглосуточно. Невозможно спать."},
    ],
}

UK_DATA = [
    {"name": "УК Северная", "email": "uk-severnaya@nvartovsk.ru"},
    {"name": "УК Центральная", "email": "uk-central@nvartovsk.ru"},
    {"name": "ТСЖ Мира", "email": "tsj-mira@nvartovsk.ru"},
    {"name": "УК Нефтяник", "email": "uk-neftyanik@nvartovsk.ru"},
    {"name": "ООО Домсервис", "email": "domservice@nvartovsk.ru"},
]

def generate_complaints(count: int = 25):
    """Generate test complaints."""
    complaints = []
    
    for i in range(count):
        category = random.choice(CATEGORIES)
        location = random.choice(LOCATIONS)
        template = random.choice(COMPLAINT_TEMPLATES.get(category, COMPLAINT_TEMPLATES['Прочее']))
        uk = random.choice(UK_DATA)
        
        # Random date within last 30 days
        days_ago = random.randint(0, 30)
        created_at = datetime.now() - timedelta(days=days_ago, hours=random.randint(0, 23), minutes=random.randint(0, 59))
        
        # Weight towards open status
        status = random.choices(STATUSES, weights=[50, 25, 15, 10])[0]
        
        # Add some randomness to coordinates (within ~500m)
        lat_offset = random.uniform(-0.003, 0.003)
        lng_offset = random.uniform(-0.003, 0.003)
        
        complaint = {
            "external_id": f"test-{i+1:04d}",
            "category": category,
            "summary": template["summary"],
            "description": template["description"],
            "address": location["address"],
            "lat": location["lat"] + lat_offset,
            "lng": location["lng"] + lng_offset,
            "status": status,
            "source": "test_seed",
            "source_name": "Тестовые данные",
            "uk_name": uk["name"],
            "uk_email": uk["email"],
            "supporters": random.randint(0, 50),
            "created_at": created_at.isoformat(),
        }
        complaints.append(complaint)
    
    return complaints


def clear_test_data():
    """Clear existing test data."""
    print("🗑️  Очистка существующих тестовых данных...")
    
    # Delete test complaints
    response = requests.delete(
        f"{API_URL}/complaints",
        headers=HEADERS,
        params={"source": "eq.test_seed"}
    )
    
    if response.status_code in [200, 204]:
        print("✅ Тестовые данные очищены")
    else:
        print(f"⚠️  Ответ при очистке: {response.status_code}")


def insert_complaints(complaints: list):
    """Insert complaints into Supabase."""
    print(f"📤 Загрузка {len(complaints)} жалоб в Supabase...")
    
    # Insert in batches of 10
    batch_size = 10
    inserted = 0
    
    for i in range(0, len(complaints), batch_size):
        batch = complaints[i:i + batch_size]
        
        response = requests.post(
            f"{API_URL}/complaints",
            headers=HEADERS,
            json=batch
        )
        
        if response.status_code == 201:
            inserted += len(batch)
            print(f"  ✓ Batch {i // batch_size + 1}: {len(batch)} записей")
        else:
            print(f"  ✗ Batch {i // batch_size + 1} error: {response.status_code}")
            print(f"    {response.text[:200]}")
    
    return inserted


def verify_data():
    """Verify inserted data."""
    print("\n🔍 Проверка данных...")
    
    # Get count
    response = requests.get(
        f"{API_URL}/complaints",
        headers={**HEADERS, 'Prefer': 'count=exact'},
        params={"select": "id", "source": "eq.test_seed"}
    )
    
    if 'content-range' in response.headers:
        count_str = response.headers['content-range']
        total = count_str.split('/')[-1]
        print(f"✅ Всего тестовых записей: {total}")
    
    # Get sample
    response = requests.get(
        f"{API_URL}/complaints",
        headers=HEADERS,
        params={
            "select": "id,category,summary,address,lat,lng,status,created_at",
            "order": "created_at.desc",
            "limit": 5
        }
    )
    
    if response.status_code == 200:
        data = response.json()
        print("\n📋 Последние 5 записей:")
        for item in data:
            print(f"  • [{item['category']}] {item['summary'][:40]}... ({item['status']})")


def update_stats():
    """Update stats table."""
    print("\n📊 Обновление статистики...")
    
    # Get category counts
    response = requests.get(
        f"{API_URL}/complaints",
        headers=HEADERS,
        params={"select": "category"}
    )
    
    if response.status_code == 200:
        data = response.json()
        by_category = {}
        for item in data:
            cat = item['category']
            by_category[cat] = by_category.get(cat, 0) + 1
        
        stats_data = {
            "key": "realtime_stats",
            "data": {
                "total_complaints": len(data),
                "by_category": by_category,
                "last_updated": datetime.now().isoformat()
            }
        }
        
        # Upsert stats
        response = requests.post(
            f"{API_URL}/stats",
            headers={**HEADERS, 'Prefer': 'resolution=merge-duplicates'},
            json=stats_data
        )
        
        if response.status_code in [200, 201]:
            print(f"✅ Статистика обновлена: {len(data)} жалоб")
        else:
            print(f"⚠️  Ошибка обновления статистики: {response.status_code}")


def main():
    print("=" * 60)
    print("🌱 SUPABASE SEED: Загрузка тестовых данных")
    print("=" * 60)
    print(f"URL: {SUPABASE_URL}")
    print()
    
    # Clear old test data
    clear_test_data()
    
    # Generate and insert new data
    complaints = generate_complaints(25)
    inserted = insert_complaints(complaints)
    
    print(f"\n✅ Загружено: {inserted} жалоб")
    
    # Verify
    verify_data()
    
    # Update stats
    update_stats()
    
    print("\n" + "=" * 60)
    print("✅ ГОТОВО! Данные загружены в Supabase")
    print("=" * 60)


if __name__ == "__main__":
    main()
