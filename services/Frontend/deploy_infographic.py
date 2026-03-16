import json
import os
from pathlib import Path

import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
for env_path in (
    Path(os.getenv("SOOBSHIO_ENV_FILE", "")).expanduser()
    if os.getenv("SOOBSHIO_ENV_FILE")
    else None,
    Path.home() / ".soobshio" / "runtime.env",
    ROOT / ".env.runtime",
    ROOT / ".env",
):
    if env_path and env_path.exists():
        load_dotenv(dotenv_path=env_path, override=False)
        break

supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
supabase_key = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_SECRET_API_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_ANON_API_KEY")
    or ""
).strip()

if not supabase_url or not supabase_key:
    raise RuntimeError("SUPABASE_URL and Supabase API key must be configured")

url = f"{supabase_url}/rest/v1/infographic_data"
key = supabase_key

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

with open(
    Path(__file__).resolve().parent / "assets" / "infographic_data.json",
    "r",
    encoding="utf-8",
) as f:
    data_content = json.load(f)

# The table schema seems to have data_type and data
payload = {
    "data_type": "summary",
    "data": data_content
}

# Upsert (using on_conflict if necessary, but here we just try to patch if exists or post)
# Let's first check if 'summary' exists
check_url = f"{url}?data_type=eq.summary"
r = requests.get(check_url, headers=headers)
print(f"Check status: {r.statusCode if hasattr(r, 'statusCode') else r.status_code}")
rows = r.json()

if rows:
    # Update existing
    row_id = rows[0]['id']
    update_url = f"{url}?id=eq.{row_id}"
    r = requests.patch(update_url, headers=headers, json=payload)
    print(f"Update status: {r.status_code}")
else:
    # Insert new
    r = requests.post(url, headers=headers, json=payload)
    print(f"Insert status: {r.status_code}")
