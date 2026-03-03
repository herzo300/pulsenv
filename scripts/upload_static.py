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
    ("map.html", "text/html"),
    ("map_script.js", "application/javascript"),
    ("info.html", "text/html"),
    ("info_script_v2.js", "application/javascript"),
    ("app.html", "text/html"),
]


def main():
    from supabase import create_client

    print(f"Connecting to {SUPABASE_URL}...")
    client = create_client(SUPABASE_URL, SERVICE_KEY)
    storage = client.storage

    # Ensure bucket exists and accepts HTML/JS
    try:
        storage.get_bucket(BUCKET)
        print(f"Bucket '{BUCKET}' exists")
        storage.update_bucket(
            BUCKET,
            options={
                "public": True,
                "allowed_mime_types": [
                    "text/html", "application/javascript", "text/javascript",
                    "text/css", "image/png", "image/jpeg", "image/svg+xml",
                    "image/webp", "application/json", "application/octet-stream",
                ],
                "file_size_limit": 10485760,
            },
        )
        print("Bucket config updated")
    except Exception as e:
        print(f"Bucket check: {e}")
        try:
            storage.create_bucket(
                BUCKET,
                options={
                    "public": True,
                    "allowed_mime_types": [
                        "text/html", "application/javascript", "text/javascript",
                        "text/css", "image/png", "image/jpeg",
                    ],
                },
            )
            print(f"Bucket '{BUCKET}' created")
        except Exception as e2:
            print(f"Bucket create failed: {e2}")

    print(f"\nUploading {len(FILES)} files...")
    ok, fail = 0, 0
    bucket = storage.from_(BUCKET)

    for filename, content_type in FILES:
        filepath = os.path.join(PUBLIC_DIR, filename)
        if not os.path.exists(filepath):
            print(f"  SKIP: {filename} (not found)")
            continue

        with open(filepath, "rb") as f:
            data = f.read()

        size_kb = len(data) / 1024
        print(f"  Uploading {filename} ({size_kb:.1f} KB)...", end=" ", flush=True)

        for attempt in range(3):
            try:
                result = bucket.upload(
                    path=filename,
                    file=data,
                    file_options={
                        "content-type": content_type,
                        "upsert": "true",
                    },
                )
                print("OK")
                ok += 1
                break
            except Exception as e:
                err_msg = str(e)
                if "Duplicate" in err_msg or "already exists" in err_msg:
                    # File exists, try update
                    try:
                        bucket.update(
                            path=filename,
                            file=data,
                            file_options={"content-type": content_type},
                        )
                        print("OK (updated)")
                        ok += 1
                        break
                    except Exception as e2:
                        print(f"update failed: {e2}")

                if attempt < 2:
                    print(f"\n    retry {attempt+1}/3: {err_msg[:100]}")
                    time.sleep(3)
                else:
                    print(f"FAIL: {err_msg[:150]}")
                    fail += 1

        time.sleep(1)

    print(f"\nResult: {ok} OK, {fail} FAIL")
    if ok > 0:
        base = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET}"
        print("\nPublic URLs:")
        for f, _ in FILES:
            print(f"  {base}/{f}")


if __name__ == "__main__":
    main()
