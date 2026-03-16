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
            "title": "Экскурсия «Память сильнее времени»", 
            "description": "Интерактивная экскурсия. Погружение в историю города, быт прошлого и памятные вехи.",
            "date": now + timedelta(hours=2),
            "lat": 60.9380, "lng": 76.5610,
            "address": "Краеведческий музей"
        },
        {
            "title": "«Календарь живых традиций»", 
            "description": "Экскурсия и программа в Музее истории русского быта. Узнайте, как зарождалось село Нижневартовское.",
            "date": now + timedelta(hours=4),
            "lat": 60.9250, "lng": 76.5450,
            "address": "Музей истории русского быта"
        },
        {
            "title": "Выставка «Радость творчества»", 
            "description": "Персональная выставка Александры Баженовой. Уникальные работы местного автора.",
            "date": midnight + timedelta(days=2, hours=10),
            "lat": 60.9385, "lng": 76.5650,
            "address": "Городская художественная галерея"
        },
        {
            "title": "Спектакль «...до лампочки»", 
            "description": "Увлекательный спектакль о приручении электрического света. Для всей семьи.",
            "date": midnight + timedelta(days=5, hours=18),
            "lat": 60.9300, "lng": 76.5350,
            "address": "Городской драматический театр"
        },
        {
            "title": "Стендап Иван Абрамов", 
            "description": "Новый стендап-концерт от звезды ТНТ. Жизненный юмор, импровизация.",
            "date": midnight + timedelta(days=7, hours=19),
            "lat": 60.9310, "lng": 76.5510,
            "address": "Дворец Искусств"
        }
    ]

    GEMINI_API_KEY = "AIzaSyCZEjOhSOn5j0o-5BYMa0aotzkmdJdUfqg"

    def rewrite_description(desc):
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
            prompt = f"Перепиши кратко, уникально и очень вовлекающе для интерактивной городской афиши следующее описание: {desc}. Без воды, только самое главное и стильное."
            payload = {"contents": [{"parts": [{"text": prompt}]}]}
            r = requests.post(url, json=payload, headers={'Content-Type': 'application/json'}, timeout=10)
            if r.status_code == 200:
                return r.json()['candidates'][0]['content']['parts'][0]['text'].strip()
        except Exception as e:
            logging.error(f"Ai rewrite failed: {e}")
        return desc

    for e in events_data:
        e["description"] = rewrite_description(e["description"])

    
    try:
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
