import requests
import json
import os
from pathlib import Path

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

# get UK data
# since it's local, we can read opendata_full.json
root_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "opendata_full.json")
with open(root_path, "r", encoding="utf-8") as f:
    full_data = json.load(f)
    uk_data = full_data.get("listoumd", {}).get("rows", [])

# upload to Supabase
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

payload = {
    "data_type": "uk_list",
    "data": uk_data
}

check_url = f"{url}?data_type=eq.uk_list"
r = requests.get(check_url, headers=headers)
rows = r.json()

if rows:
    row_id = rows[0]['id']
    update_url = f"{url}?id=eq.{row_id}"
    r = requests.patch(update_url, headers=headers, json=payload)
    print(f"Update UK status: {r.status_code}")
else:
    r = requests.post(url, headers=headers, json=payload)
    print(f"Insert UK status: {r.status_code}")
