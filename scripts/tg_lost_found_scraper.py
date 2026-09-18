#!/usr/bin/env python3
"""
tg_lost_found_scraper.py

Автоматический скрапер/парсер объявлений «Бюро Находок» и «Потеряшек»
из публичных Telegram-каналов города Нижневартовска:
  - t.me/s/bureau_nv
  - t.me/s/podslushano_dogs_nv
  - t.me/s/chp_nv_86
  - t.me/s/nv_lost_found
  - t.me/s/nizhnevartovsk_animals

Извлекает публикации, фото, категории и адреса, дедуплицирует и сохраняет в БД.
"""

import os
import sys
import re
import time
import json
import random
import hashlib
import urllib.request
from datetime import datetime, UTC

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

NV_STREETS = [
    {"name": "Героев Самотлора", "lat": 60.9412, "lng": 76.6185},
    {"name": "Ленина", "lat": 60.9378, "lng": 76.5712},
    {"name": "Дружбы Народов", "lat": 60.9442, "lng": 76.5910},
    {"name": "Мира", "lat": 60.9431, "lng": 76.5824},
    {"name": "Чапаева", "lat": 60.9325, "lng": 76.5898},
    {"name": "Победы", "lat": 60.9351, "lng": 76.5621},
    {"name": "Омская", "lat": 60.9362, "lng": 76.5489},
    {"name": "Интернациональная", "lat": 60.9548, "lng": 76.5790},
    {"name": "60 лет Октября", "lat": 60.9298, "lng": 76.5540},
    {"name": "Ханты-Мансийская", "lat": 60.9465, "lng": 76.6210},
]

TG_CHANNELS = [
    {"channel": "bureau_nv", "name": "Telegram: Бюро Находок НВ", "default_cat": "Найдена вещь"},
    {"channel": "podslushano_dogs_nv", "name": "Telegram: Потеряшки Нижневартовск", "default_cat": "Потеряно животное"},
    {"channel": "chp_nv_86", "name": "Telegram: ЧП Нижневартовск", "default_cat": "Потеряна вещь"},
    {"channel": "nv_lost_found", "name": "Telegram: Находки НВ", "default_cat": "Найдена вещь"},
    {"channel": "nizhnevartovsk_animals", "name": "Telegram: Животные Нижневартовск", "default_cat": "Найдено животное"},
]

def hash_text(text: str) -> str:
    clean = re.sub(r'\s+', '', text.lower())
    return hashlib.md5(clean.encode('utf-8')).hexdigest()

def detect_category(text: str, default_cat: str) -> str:
    lower = text.lower()
    if 'найден' in lower or 'нашли' in lower or 'прибился' in lower:
        if any(w in lower for w in ['собак', 'кот', 'кош', 'щенок', 'пес', 'хаски', 'животн']):
            return 'Найдено животное'
        return 'Найдена вещь'
    if 'потеря' in lower or 'пропал' in lower or 'убежал' in lower or 'утерян' in lower:
        if any(w in lower for w in ['собак', 'кот', 'кош', 'щенок', 'пес', 'хаски', 'животн']):
            return 'Потеряно животное'
        return 'Потеряна вещь'
    return default_cat

def geocode_nv_text(text: str) -> dict:
    for st in NV_STREETS:
        if st["name"].lower() in text.lower():
            return {
                "address": f"ул. {st['name']}, Нижневартовск",
                "lat": st["lat"],
                "lng": st["lng"]
            }
    # Street not mentioned in the post: do not invent a random location.
    return {"address": "Нижневартовск", "lat": None, "lng": None}

import ssl

def scrape_tg_channel(cfg: dict) -> list[dict]:
    items = []
    url = f"https://t.me/s/{cfg['channel']}"
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    
    try:
        req = urllib.request.Request(url, headers=headers)
        try:
            opener = urllib.request.build_opener(
                urllib.request.ProxyHandler({}),
            )
            with opener.open(req, timeout=10) as resp:
                html = resp.read().decode('utf-8', errors='ignore')
        except urllib.error.URLError:
            # Server contour: internet only via tor SOCKS proxy
            import socket as _socket

            import socks as _socks

            _socks.set_default_proxy(_socks.SOCKS5, "tor", 9050)
            _socket.socket = _socks.socksocket
            with urllib.request.urlopen(req, timeout=20) as resp:
                html = resp.read().decode('utf-8', errors='ignore')

        # Parse whole message blocks so text and photos stay attached to the same post
        blocks = re.findall(r'<div class="tgme_widget_message_wrap[^"]*".*?(?=<div class="tgme_widget_message_wrap|</body>)', html, re.DOTALL)
        if not blocks:
            blocks = [html]
        for block in blocks[:20]:
            m_text = re.search(r'<div class="tgme_widget_message_text js-message_text"[^>]*>(.*?)</div>', block, re.DOTALL)
            if not m_text:
                continue
            clean_p = re.sub(r'<[^>]+>', ' ', m_text.group(1)).strip()
            if len(clean_p) < 15:
                continue
            cat = detect_category(clean_p, cfg["default_cat"])
            geo = geocode_nv_text(clean_p)
            first_line = clean_p.split('.')[0] if '.' in clean_p else clean_p[:60]

            m_photo = re.search(r'background-image:url\(\'(https://[^\s\']+?cdn\d*\.telesco\.pe[^\s\']+?)\'\)', block)
            photo = m_photo.group(1) if m_photo else None

            items.append({
                "title": first_line[:150],
                "description": clean_p,
                "category": cat,
                "address": geo["address"],
                "lat": geo["lat"],
                "lng": geo["lng"],
                "photo_url": photo,
                "source": f"tg:@{cfg['channel']}",
                "telegram_channel": cfg["name"]
            })
    except Exception as e:
        print(f"[TG SCRAPER] Не удалось загрузить @{cfg['channel']}: {e}")
        
    return items

def run_tg_scraper(save_db=True) -> int:
    print("\n--- [TG SCRAPER] Запуск сканирования Telegram каналов ---")
    all_parsed = []
    for ch in TG_CHANNELS:
        res = scrape_tg_channel(ch)
        print(f"  Канал Telegram '{ch['name']}': получено {len(res)} сообщений.")
        all_parsed.extend(res)
        
    if not save_db or not all_parsed:
        return len(all_parsed)
        
    saved = 0
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        db = SessionLocal()
        
        for item in all_parsed:
            exists = db.query(Report).filter(
                Report.title == item['title'],
                Report.description == item['description']
            ).first()
            if exists:
                continue
                
            now = datetime.now(UTC).replace(tzinfo=None)
            description = item["description"]
            if item.get("photo_url"):
                description += f"\n\nФото: {item['photo_url']}"
            rep = Report(
                title=item["title"],
                description=description,
                category=item["category"],
                address=item["address"],
                lat=item["lat"],
                lng=item["lng"],
                status="open",
                source=item["source"],
                telegram_channel=item["telegram_channel"],
                city="nizhnevartovsk",
                created_at=now,
                updated_at=now
            )
            db.add(rep)
            saved += 1

        db.commit()
        print(f"[TG SCRAPER SUCCESS] Сохранено {saved} новых объявлений из TG в базу данных.")
    except Exception as e:
        db.rollback()
        print(f"[TG SCRAPER ERROR] Ошибка записи в БД: {e}")
    finally:
        db.close()

    return saved

if __name__ == "__main__":
    run_tg_scraper(save_db=True)
