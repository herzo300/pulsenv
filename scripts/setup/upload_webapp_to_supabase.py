#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import io
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    import requests
    from dotenv import load_dotenv
except ImportError:
    print('Install dependencies: pip install requests python-dotenv')
    sys.exit(1)

load_dotenv()
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

SUPABASE_URL = os.getenv('SUPABASE_URL')
SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_SERVICE_KEY')
BUCKET_NAME = 'apps'
PUBLIC_DIR = Path(__file__).parent.parent.parent / 'public'
FILES_TO_UPLOAD = [
    'map.html',
    'info.html',
    'cesium_view.html',
    'map_script.js',
    'info_script_v2.js',
    'info_story_merge.css',
    'info_story_merge.js',
    'splash_system.js',
    'cameras_nv.json',
    'audio/splash-aurora.mp3',
    'audio/splash-grid.mp3',
    'audio/splash-pulse.mp3',
]
MIME_TYPES = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.mp3': 'audio/mpeg',
}


def get_headers(content_type=None):
    headers = {
        'Authorization': f'Bearer {SERVICE_KEY}',
        'apikey': SERVICE_KEY,
    }
    if content_type:
        headers['Content-Type'] = content_type
    return headers


def create_or_update_bucket():
    data = {
        'name': BUCKET_NAME,
        'public': True,
        'file_size_limit': 314572800,
        'allowed_mime_types': None,
    }

    response = requests.get(f'{SUPABASE_URL}/storage/v1/bucket', headers=get_headers(), timeout=30)
    if response.status_code == 200 and any(bucket.get('name') == BUCKET_NAME for bucket in response.json()):
        print(f"Bucket '{BUCKET_NAME}' already exists. Updating config...")
        update = requests.put(
            f'{SUPABASE_URL}/storage/v1/bucket/{BUCKET_NAME}',
            headers=get_headers('application/json'),
            json=data,
            timeout=30,
        )
        return update.status_code in (200, 204)

    create = requests.post(
        f'{SUPABASE_URL}/storage/v1/bucket',
        headers=get_headers('application/json'),
        json=data,
        timeout=30,
    )
    if create.status_code in (200, 201) or 'already exists' in create.text.lower():
        print(f"Bucket '{BUCKET_NAME}' is ready")
        requests.put(
            f'{SUPABASE_URL}/storage/v1/bucket/{BUCKET_NAME}',
            headers=get_headers('application/json'),
            json=data,
            timeout=30,
        )
        return True

    print(f"Bucket create failed: {create.status_code} - {create.text}")
    return False


def upload_file(file_path, storage_path):
    mime_type = MIME_TYPES.get(file_path.suffix.lower(), 'application/octet-stream')
    with open(file_path, 'rb') as handle:
        payload = handle.read()

    url = f'{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{storage_path}'
    response = requests.post(url, headers=get_headers(mime_type), data=payload, timeout=300)
    if response.status_code == 409 or 'duplicate' in response.text.lower() or 'already exists' in response.text.lower():
        response = requests.put(url, headers=get_headers(mime_type), data=payload, timeout=300)

    if response.status_code in (200, 201):
        public_url = f'{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}'
        print(f'  OK {storage_path} -> {public_url}')
        return True

    print(f'  FAIL {storage_path}: {response.status_code} - {response.text[:200]}')
    return False


def main():
    if not SUPABASE_URL or not SERVICE_KEY:
        print('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing in .env')
        sys.exit(1)

    print(f'Preparing bucket {BUCKET_NAME}...')
    if not create_or_update_bucket():
        sys.exit(1)

    print(f'Uploading files to {BUCKET_NAME}...')
    failed = []
    for relative_path in FILES_TO_UPLOAD:
        source = PUBLIC_DIR / relative_path
        if not source.exists():
            print(f'  SKIP {relative_path} (not found)')
            failed.append(relative_path)
            continue
        if not upload_file(source, relative_path.replace('\\', '/')):
            failed.append(relative_path)

    if failed:
        print('\nCompleted with failures:')
        for item in failed:
            print(f' - {item}')
        sys.exit(1)

    print('\nUpload complete.')


if __name__ == '__main__':
    main()
