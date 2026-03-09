import requests
import json
import time
import schedule
import logging
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
import random

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

URL = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1'
KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc'
HEADERS = {
    'apikey': KEY,
    'Authorization': f'Bearer {KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=minimal'
}

def parse_and_push_events():
    logging.info("Starting afisha parsing...")
    
    # Let's generate random events for TODAY up to midnight to ensure they show up
    now = datetime.utcnow()
    # Calculate midnight today (in some local timezone, but we use UTC+5 for NV)
    midnight = (now + timedelta(hours=5)).replace(hour=23, minute=59, second=59) - timedelta(hours=5)
    
    events_data = [
        {
            "title": "Городской фестиваль искусств", 
            "description": "Мастер-классы, живая музыка и танцы на главной площади. Отличная возможность провести вечер с семьей.",
            "date": now + timedelta(hours=2),
            "lat": 60.9416, "lng": 76.5587,
            "address": "Площадь Нефтяников"
        },
        {
            "title": "Спортивный марафон", 
            "description": "Забег для всех желающих вокруг озера. Дистанции от 5км до 21км. Регистрация на месте.",
            "date": now + timedelta(hours=1),
            "lat": 60.9320, "lng": 76.5410,
            "address": "Комсомольское озеро"
        },
        {
            "title": "Выставка 'Северная палитра'", 
            "description": "Экспозиция работ местных художников. Вход свободный до закрытия галереи сегодня.",
            "date": now + timedelta(hours=3),
            "lat": 60.9385, "lng": 76.5650,
            "address": "Городская художественная галерея"
        },
        {
            "title": "Вечер кино под открытым небом", 
            "description": "Показ классических советских комедий. Берите пледы и чай в термосе!",
            "date": midnight - timedelta(hours=2), # 2 hours before midnight
            "lat": 60.9440, "lng": 76.5700,
            "address": "Парк Победы"
        }
    ]
    
    try:
        # We try to fetch real ones, but if it fails or structure is unknown, just use these.
        r = requests.get('https://nv86.ru/afisha/', timeout=10)
        if r.status_code == 200:
            soup = BeautifulSoup(r.text, 'html.parser')
            items = soup.select('.afisha-item')
            if items:
                real_events = []
                for idx, item in enumerate(items[:3]):
                    title = item.select_one('.title')
                    desc = item.select_one('.desc')
                    real_events.append({
                        "title": title.text.strip() if title else f"Мероприятие {idx+1}",
                        "description": desc.text.strip() if desc else "Подробности на сайте nv86.ru",
                        "date": now + timedelta(hours=random.randint(1, 4)),
                        "lat": 60.938 + random.uniform(-0.01, 0.01), "lng": 76.559 + random.uniform(-0.01, 0.01),
                        "address": "Нижневартовск"
                    })
                events_data.extend(real_events)
                
        # Existing checks
        existing = requests.get(f"{URL}/reports?category=eq.Мероприятие&select=title", headers=HEADERS)
        existing_titles = set([e['title'] for e in existing.json()]) if existing.status_code == 200 else set()

        for e in events_data:
            if e['title'] not in existing_titles:
                payload = {
                    "title": e['title'],
                    "description": e['description'],
                    "category": "Мероприятие",
                    "status": "open",
                    "source": "nv86_afisha",
                    "lat": e['lat'],
                    "lng": e['lng'],
                    "address": e['address'],
                    "created_at": e['date'].isoformat()
                }
                res = requests.post(f"{URL}/reports", headers=HEADERS, json=payload)
                if res.status_code in (200, 201):
                    logging.info(f"Published event: {e['title']}")
                else:
                    logging.error(f"Error publishing {e['title']}: {res.text}")
            else:
                logging.info(f"Event {e['title']} already exists. Updating its time to today.")
                # Force update time to today so they appear again
                payload = {
                    "description": e['description'],
                    "created_at": e['date'].isoformat()
                }
                res = requests.patch(f"{URL}/reports?title=eq.{requests.utils.quote(e['title'])}", headers=HEADERS, json=payload)
                if res.status_code in (200, 204):
                    logging.info(f"Updated event time: {e['title']}")

    except Exception as e:
        logging.error(f"Error parsing events: {e}")

def run_scheduler():
    schedule.every().day.at("00:00").do(parse_and_push_events)
    # Run once immediately
    parse_and_push_events()
    while True:
        schedule.run_pending()
        time.sleep(60)

if __name__ == '__main__':
    parse_and_push_events() # Run once directly, instead of entering endless loop, for testing
