import requests
import json
import os
import sys

# get UK data
# since it's local, we can read opendata_full.json
root_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "opendata_full.json")
with open(root_path, "r", encoding="utf-8") as f:
    full_data = json.load(f)
    uk_data = full_data.get("listoumd", {}).get("rows", [])

# upload to Supabase
url = "https://xpainxohbdoruakcijyq.supabase.co/rest/v1/infographic_data"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc"

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
