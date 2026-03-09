import requests
import json

url = "https://xpainxohbdoruakcijyq.supabase.co/rest/v1/infographic_data"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc"

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

with open("assets/infographic_data.json", "r", encoding="utf-8") as f:
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
