import requests
import json
import sys

URL = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc'
HEADERS = {
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}',
    'Content-Type': 'application/json'
}

def check_complaints():
    res = requests.get(f"{URL}/complaints?limit=1", headers=HEADERS)
    print("COMPLAINTS TABLE:", res.status_code, res.text)

def check_reports():
    res = requests.get(f"{URL}/reports?limit=1", headers=HEADERS)
    print("REPORTS TABLE:", res.status_code, res.text)

def create_events_table_if_needed():
    # Attempt to POST to city_events to see if it exists
    test_data = {
        "title": "Test Event",
        "description": "Test Desc",
        "event_date": "2026-03-10T12:00:00Z",
        "category": "Крайнее событие",
        "latitude": 60.9344,
        "longitude": 76.5531,
        "source_url": "https://nv86.ru"
    }
    res = requests.post(f"{URL}/city_events", headers=HEADERS, json=test_data)
    print("CREATE EVENT TEST:", res.status_code, res.text)

if __name__ == '__main__':
    check_complaints()
    check_reports()
    create_events_table_if_needed()
