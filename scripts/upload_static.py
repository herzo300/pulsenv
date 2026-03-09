"""Upload static files to Supabase Storage using the official Python SDK."""

import os
import sys
import time
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

if not SUPABASE_URL or not SERVICE_KEY:
    print("ERROR: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set")
    sys.exit(1)

PUBLIC_DIR = os.path.join(os.path.dirname(__file__), "..", "public")
BUCKET = "static"

FILES = [
    ("map.html", "map.html", "text/html"),
    ("map_script.js", "map_script.js", "application/javascript"),
    ("city_story.html", "city_story.html", "text/html"),
    ("info.html", "info.html", "text/html"),
    ("info_script_v2.js", "info_script_v2.js", "application/javascript"),
    ("app.html", "app.html", "text/html"),
    ("infographic_data.json", "infographic_data.json", "application/json"),
    ("cesium_view.html", "cesium_view.html", "text/html"),
    ("cameras_nv.json", "cameras_nv.json", "application/json"),
    ("../services/Frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk", "citypulse.apk", "application/octet-stream"),
]

def main():
    try:
        from supabase import create_client
    except ImportError:
        print("ERROR: supabase library not found. Run: python -m pip install supabase")
        return

    print(f"Connecting to {SUPABASE_URL}...")
    client = create_client(SUPABASE_URL, SERVICE_KEY)
    storage = client.storage

    # Ensure bucket accepts larger files
    try:
        storage.update_bucket(BUCKET, options={"file_size_limit": 104857600}) # 100MB
        print(f"Bucket '{BUCKET}' limit updated to 100MB")
    except: pass

    print(f"Uploading {len(FILES)} files...")
    ok, fail = 0, 0
    bucket = storage.from_(BUCKET)

    for local_name, target_name, content_type in FILES:
        filepath = os.path.join(PUBLIC_DIR, local_name)
        if not os.path.exists(filepath):
            print(f"  SKIP: {local_name} (not found)")
            continue

        with open(filepath, "rb") as f:
            data = f.read()

        size_kb = len(data) / 1024
        print(f"  Uploading {local_name} -> {target_name} ({size_kb:.1f} KB)...", end=" ", flush=True)

        try:
            # Try upload with upsert=true
            bucket.upload(
                path=target_name,
                file=data,
                file_options={
                    "content-type": content_type,
                    "upsert": "true",
                },
            )
            print("OK")
            ok += 1
        except Exception as e:
             # If upload fails, try update
            try:
                bucket.update(
                    path=target_name,
                    file=data,
                    file_options={"content-type": content_type},
                )
                print("OK (updated)")
                ok += 1
            except Exception as e2:
                print(f"FAIL: {str(e2)[:100]}")
                fail += 1

        time.sleep(0.5)

    print(f"\nResult: {ok} OK, {fail} FAIL")
    if ok > 0:
        base = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}"
        print(f"\nPublic APK URL: {base}/citypulse.apk")

if __name__ == "__main__":
    main()
