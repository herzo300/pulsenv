"""Upload current public assets and release APK to Supabase Storage."""

import os
import sys
import time
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

SUPABASE_URL = os.getenv('SUPABASE_URL', '')
SERVICE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')

if not SUPABASE_URL or not SERVICE_KEY:
    print('ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set')
    sys.exit(1)

PUBLIC_DIR = os.path.join(os.path.dirname(__file__), '..', 'public')
BUCKET = 'apps'


def resolve_apk_path():
    candidates = [
        os.path.join(
            PUBLIC_DIR,
            '..',
            'services',
            'Frontend',
            'build',
            'app',
            'outputs',
            'flutter-apk',
            'app-arm64-v8a-release.apk',
        ),
        os.path.join(
            PUBLIC_DIR,
            '..',
            'services',
            'Frontend',
            'build',
            'app',
            'outputs',
            'flutter-apk',
            'app-release.apk',
        ),
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


FILES = [
    ('map.html', 'map.html', 'text/html'),
    ('map_script.js', 'map_script.js', 'application/javascript'),
    ('info.html', 'info.html', 'text/html'),
    ('info_script_v2.js', 'info_script_v2.js', 'application/javascript'),
    ('info_story_merge.css', 'info_story_merge.css', 'text/css'),
    ('info_story_merge.js', 'info_story_merge.js', 'application/javascript'),
    ('cesium_view.html', 'cesium_view.html', 'text/html'),
    ('cameras_nv.json', 'cameras_nv.json', 'application/json'),
    ('splash_system.js', 'splash_system.js', 'application/javascript'),
    ('audio/splash-aurora.mp3', 'audio/splash-aurora.mp3', 'audio/mpeg'),
    ('audio/splash-grid.mp3', 'audio/splash-grid.mp3', 'audio/mpeg'),
    ('audio/splash-pulse.mp3', 'audio/splash-pulse.mp3', 'audio/mpeg'),
]


def main():
    try:
        from supabase import create_client
    except ImportError:
        print('ERROR: supabase library not found. Run: python -m pip install supabase')
        return

    print(f'Connecting to {SUPABASE_URL}...')
    client = create_client(SUPABASE_URL, SERVICE_KEY)
    storage = client.storage

    try:
        storage.update_bucket(BUCKET, options={'file_size_limit': 314572800})
        print(f"Bucket '{BUCKET}' limit updated to 300MB")
    except Exception:
        pass

    upload_items = list(FILES)
    apk_path = resolve_apk_path()
    if apk_path:
        upload_items.append((apk_path, 'citypulse.apk', 'application/vnd.android.package-archive'))

    print(f'Uploading {len(upload_items)} files...')
    ok, fail = 0, 0
    bucket = storage.from_(BUCKET)

    for local_name, target_name, content_type in upload_items:
        filepath = local_name if os.path.isabs(local_name) else os.path.join(PUBLIC_DIR, local_name)
        if not os.path.exists(filepath):
            print(f'  SKIP: {local_name} (not found)')
            continue

        with open(filepath, 'rb') as handle:
            data = handle.read()

        size_kb = len(data) / 1024
        print(f'  Uploading {target_name} ({size_kb:.1f} KB)...', end=' ', flush=True)

        try:
            bucket.upload(
                path=target_name,
                file=data,
                file_options={
                    'content-type': content_type,
                    'upsert': 'true',
                },
            )
            print('OK')
            ok += 1
        except Exception:
            try:
                bucket.update(
                    path=target_name,
                    file=data,
                    file_options={'content-type': content_type},
                )
                print('OK (updated)')
                ok += 1
            except Exception as error:
                print(f'FAIL: {str(error)[:160]}')
                fail += 1

        time.sleep(0.3)

    print(f'\nResult: {ok} OK, {fail} FAIL')
    if ok > 0:
        base = f'{SUPABASE_URL}/storage/v1/object/public/{BUCKET}'
        print(f'Public map URL: {base}/map.html')
        print(f'Public info URL: {base}/info.html')
        print(f'Public APK URL: {base}/citypulse.apk')

    if fail:
        sys.exit(1)


if __name__ == '__main__':
    main()
