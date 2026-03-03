#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Загрузка PNG маркеров в Supabase Storage

Требования:
1. Установить service_role ключ в .env (SUPABASE_SERVICE_KEY)
   - Получить из: https://supabase.com/dashboard/project/xpainxohbdoruakcijyq
   - Settings → API → service_role (secret) - НЕ anon ключ!

2. Поместить PNG файлы маркеров в папку cloudflare-worker/markers/

Использование:
    python scripts/setup/upload_markers_to_supabase.py
"""

import os
import sys
import base64
from pathlib import Path

# Добавляем корень проекта в путь
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    import requests
    from dotenv import load_dotenv
except ImportError:
    print("Установите зависимости: pip install requests python-dotenv")
    sys.exit(1)

load_dotenv()

# Fix Windows console encoding
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://xpainxohbdoruakcijyq.supabase.co")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")
ANON_KEY = os.getenv("SUPABASE_ANON_API_KEY")

BUCKET_NAME = "static"
MARKERS_DIR = Path(__file__).parent.parent.parent / "public" / "markers"


def check_service_key():
    """Проверяет, что установлен service_role ключ (не anon)"""
    if not SERVICE_KEY:
        print("❌ SUPABASE_SERVICE_KEY не установлен в .env")
        return False
    
    # Декодируем JWT чтобы проверить роль
    try:
        payload = SERVICE_KEY.split('.')[1]
        # Добавляем padding для base64
        padding = 4 - len(payload) % 4
        if padding != 4:
            payload += '=' * padding
        import json
        decoded = json.loads(base64.b64decode(payload))
        role = decoded.get('role', 'unknown')
        
        if role == 'anon':
            print("❌ SUPABASE_SERVICE_KEY содержит anon ключ, а не service_role!")
            print("   Получите service_role ключ из Supabase Dashboard:")
            print("   https://supabase.com/dashboard/project/xpainxohbdoruakcijyq")
            print("   Settings → API → service_role (secret)")
            return False
        
        print(f"✅ Ключ: role={role}")
        return True
    except Exception as e:
        print(f"⚠️ Не удалось проверить роль ключа: {e}")
        return True  # Продолжаем, может сработает


def get_headers():
    """Возвращает заголовки для API запросов"""
    return {
        "Authorization": f"Bearer {SERVICE_KEY}",
        "apikey": SERVICE_KEY,
    }


def create_bucket():
    """Создает публичный бакет для статических файлов"""
    headers = get_headers()
    headers["Content-Type"] = "application/json"
    
    # Проверяем существует ли бакет
    r = requests.get(f"{SUPABASE_URL}/storage/v1/bucket", headers=headers, timeout=30)
    if r.status_code == 200:
        buckets = r.json()
        if any(b.get('name') == BUCKET_NAME for b in buckets):
            print(f"✅ Бакет '{BUCKET_NAME}' уже существует")
            return True
    
    # Создаем бакет
    data = {
        "name": BUCKET_NAME,
        "public": True,
        "file_size_limit": 5242880,  # 5MB
        "allowed_mime_types": ["image/png", "image/svg+xml", "image/jpeg", "image/webp"]
    }
    
    r = requests.post(f"{SUPABASE_URL}/storage/v1/bucket", headers=headers, json=data, timeout=30)
    
    if r.status_code in (200, 201):
        print(f"✅ Бакет '{BUCKET_NAME}' создан")
        return True
    elif "already exists" in r.text.lower() or "duplicate" in r.text.lower():
        print(f"✅ Бакет '{BUCKET_NAME}' уже существует")
        return True
    else:
        print(f"❌ Ошибка создания бакета: {r.status_code} - {r.text}")
        return False


def upload_file(file_path: Path, storage_path: str):
    """Загружает файл в Storage"""
    headers = get_headers()
    
    # Определяем MIME тип
    mime_types = {
        '.png': 'image/png',
        '.svg': 'image/svg+xml',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.webp': 'image/webp'
    }
    mime_type = mime_types.get(file_path.suffix.lower(), 'application/octet-stream')
    headers["Content-Type"] = mime_type
    
    with open(file_path, 'rb') as f:
        data = f.read()
    
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{storage_path}"
    
    # Сначала пробуем POST (создание)
    r = requests.post(url, headers=headers, data=data, timeout=60)
    
    if r.status_code == 409:  # Уже существует - обновляем
        r = requests.put(url, headers=headers, data=data, timeout=60)
    
    if r.status_code in (200, 201):
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}"
        print(f"  ✅ {file_path.name} → {public_url}")
        return public_url
    else:
        print(f"  ❌ {file_path.name}: {r.status_code} - {r.text}")
        return None


def upload_markers():
    """Загружает все маркеры из папки markers"""
    if not MARKERS_DIR.exists():
        print(f"📁 Создаю папку для маркеров: {MARKERS_DIR}")
        MARKERS_DIR.mkdir(parents=True, exist_ok=True)
        
        # Создаем примеры SVG маркеров
        create_sample_markers()
    
    files = list(MARKERS_DIR.glob("*.png")) + list(MARKERS_DIR.glob("*.svg"))
    
    if not files:
        print(f"⚠️ Нет файлов маркеров в {MARKERS_DIR}")
        print("   Поместите PNG или SVG файлы в эту папку")
        return []
    
    print(f"\n📤 Загрузка {len(files)} файлов маркеров...")
    
    uploaded = []
    for file_path in files:
        url = upload_file(file_path, f"markers/{file_path.name}")
        if url:
            uploaded.append((file_path.name, url))
    
    return uploaded


def create_sample_markers():
    """Создает примеры SVG маркеров для каждой категории"""
    categories = {
        'zhkh': ('#14b8a6', '🏘️'),
        'roads': ('#ef4444', '🛣️'),
        'landscaping': ('#10b981', '🌳'),
        'transport': ('#3b82f6', '🚌'),
        'ecology': ('#22c55e', '♻️'),
        'safety': ('#dc2626', '🚨'),
        'lighting': ('#f59e0b', '💡'),
        'snow': ('#06b6d4', '❄️'),
        'medicine': ('#ec4899', '🏥'),
        'education': ('#8b5cf6', '🏫'),
        'parking': ('#6366f1', '🅿️'),
        'other': ('#64748b', '❔'),
    }
    
    svg_template = '''<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">
  <defs>
    <filter id="shadow" x="-50%" y="-50%" width="200%" height="200%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <circle cx="20" cy="20" r="18" fill="{color}" filter="url(#shadow)"/>
  <circle cx="20" cy="20" r="16" fill="{color}" stroke="white" stroke-width="2"/>
  <text x="20" y="26" text-anchor="middle" font-size="16">{emoji}</text>
</svg>'''
    
    print("📝 Создаю примеры SVG маркеров...")
    for name, (color, emoji) in categories.items():
        svg_content = svg_template.format(color=color, emoji=emoji)
        svg_path = MARKERS_DIR / f"marker-{name}.svg"
        svg_path.write_text(svg_content, encoding='utf-8')
        print(f"  ✅ {svg_path.name}")


def main():
    print("=" * 60)
    print("🚀 Загрузка маркеров в Supabase Storage")
    print("=" * 60)
    
    # Проверяем ключ
    if not check_service_key():
        sys.exit(1)
    
    # Создаем бакет
    print("\n📦 Проверка/создание бакета...")
    if not create_bucket():
        sys.exit(1)
    
    # Загружаем маркеры
    uploaded = upload_markers()
    
    # Итоги
    print("\n" + "=" * 60)
    if uploaded:
        print(f"✅ Успешно загружено: {len(uploaded)} файлов")
        print("\n📋 URL файлов для использования в коде:")
        for name, url in uploaded:
            print(f"  {name}: {url}")
    else:
        print("⚠️ Файлы не загружены")
    
    print("\n💡 Базовый URL для маркеров:")
    print(f"   {SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/markers/")


if __name__ == "__main__":
    main()
