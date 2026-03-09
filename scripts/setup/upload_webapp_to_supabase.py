#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
from pathlib import Path

# Add project root to path
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

SUPABASE_URL = os.getenv("SUPABASE_URL")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")

BUCKET_NAME = "webapp"
PUBLIC_DIR = Path(__file__).parent.parent.parent / "public"

def get_headers():
    return {
        "Authorization": f"Bearer {SERVICE_KEY}",
        "apikey": SERVICE_KEY,
    }

def create_bucket():
    headers = get_headers()
    headers["Content-Type"] = "application/json"
    
    r = requests.get(f"{SUPABASE_URL}/storage/v1/bucket", headers=headers, timeout=30)
    if r.status_code == 200:
        buckets = r.json()
        if any(b.get('name') == BUCKET_NAME for b in buckets):
            print(f"✅ Бакет '{BUCKET_NAME}' уже существует")
            return True
            
    data = {
        "name": BUCKET_NAME,
        "public": True,
        "file_size_limit": 5242880,
        "allowed_mime_types": ["text/html", "application/javascript", "text/css", "application/json"]
    }
    
    r = requests.post(f"{SUPABASE_URL}/storage/v1/bucket", headers=headers, json=data, timeout=30)
    if r.status_code in (200, 201):
        print(f"✅ Бакет '{BUCKET_NAME}' создан")
        # Update just in case
        data["public"] = True
        data["allowed_mime_types"] = None
        requests.put(f"{SUPABASE_URL}/storage/v1/bucket/{BUCKET_NAME}", headers=headers, json=data, timeout=30)
        return True
    elif "already exists" in r.text.lower() or "duplicate" in r.text.lower():
        print(f"✅ Бакет '{BUCKET_NAME}' уже существует. Обновляем...")
        data["public"] = True
        data["allowed_mime_types"] = None
        requests.put(f"{SUPABASE_URL}/storage/v1/bucket/{BUCKET_NAME}", headers=headers, json=data, timeout=30)
        return True
    else:
        print(f"❌ Ошибка создания бакета: {r.status_code} - {r.text}")
        return False

def upload_file(file_path: Path, storage_path: str):
    headers = get_headers()
    
    mime_types = {
        '.html': 'text/html',
        '.js': 'application/javascript',
        '.css': 'text/css',
        '.json': 'application/json'
    }
    mime_type = mime_types.get(file_path.suffix.lower(), 'application/octet-stream')
    headers["Content-Type"] = mime_type
    
    with open(file_path, 'rb') as f:
        data = f.read()
    
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{storage_path}"
    
    r = requests.post(url, headers=headers, data=data, timeout=60)
    
    if r.status_code == 409 or 'Duplicate' in r.text or 'already exists' in r.text.lower():
        r = requests.put(url, headers=headers, data=data, timeout=60)
    
    if r.status_code in (200, 201):
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}"
        print(f"  ✅ {file_path.name} → {public_url} (Type: {mime_type})")
        return public_url
    else:
        print(f"  ❌ {file_path.name}: {r.status_code} - {r.text}")
        return None

def main():
    if not SUPABASE_URL or not SERVICE_KEY:
        print("❌ Отсутствуют SUPABASE_URL или SUPABASE_SERVICE_ROLE_KEY в .env")
        sys.exit(1)
        
    print("\n📦 Проверка/создание бакета...")
    if not create_bucket():
        sys.exit(1)
        
    files_to_upload = ['map.html', 'info.html', 'cesium_view.html', 'map_script.js', 'info_script_v2.js', 'info_story_merge.css', 'info_story_merge.js', 'cameras_nv.json']
    
    print(f"\n📤 Загрузка файлов в бакет {BUCKET_NAME}...")
    
    for filename in files_to_upload:
        file_path = PUBLIC_DIR / filename
        if file_path.exists():
            upload_file(file_path, filename)
        else:
            print(f"⚠️ Файл не найден: {file_path}")

if __name__ == "__main__":
    main()
