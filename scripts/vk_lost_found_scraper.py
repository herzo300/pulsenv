#!/usr/bin/env python3
"""
vk_lost_found_scraper.py

Автоматический скрапер/парсер объявлений «Бюро Находок» и «Потеряшек»
из городских пабликов VK (Нижневартовск):
  - vk.com/bureau_nv
  - vk.com/lost_pets_nv
  - vk.com/typical.nizhnevartovsk
  - vk.com/chp_nv
  - vk.com/baraholka_nv

Извлекает:
  - Заголовок и описание поста
  - Картинки/фотографии (CDN VK)
  - Автоматически категоризирует (Потеряно/Найдено животное/вещь)
  - Геокодирует найденные адреса к координатам Нижневартовска
  - Дедуплицирует записи и сохраняет в таблицу `reports`
"""

import os
import sys
import re
import time
import json
import random
import hashlib
import urllib.request
import urllib.parse
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
    {"name": "Мусы Джалиля", "lat": 60.9310, "lng": 76.5670},
    {"name": "Маршала Жукова", "lat": 60.9405, "lng": 76.5615},
]

VK_PUBLIC_GROUPS = [
    {"domain": "bureau_nv", "name": "Бюро Находок Нижневартовск", "default_cat": "Найдена вещь"},
    {"domain": "lost_pets_nv", "name": "Потеряшки / Животные Нижневартовск", "default_cat": "Потеряно животное"},
    {"domain": "typical.nizhnevartovsk", "name": "Типичный Нижневартовск", "default_cat": "Найдена вещь"},
    {"domain": "chp_nv", "name": "ЧП Нижневартовск", "default_cat": "Потеряна вещь"},
    {"domain": "baraholka_nv", "name": "Барахолка НВ Бюро", "default_cat": "Найдена вещь"},
]

def hash_text(text: str) -> str:
    clean = re.sub(r'\s+', '', text.lower())
    return hashlib.md5(clean.encode('utf-8')).hexdigest()

def detect_category(text: str, default_cat: str) -> str:
    lower = text.lower()
    if 'найден' in lower or 'нашли' in lower or 'прибился' in lower:
        if any(w in lower for w in ['собак', 'кот', 'кош', 'щенок', 'пес', 'хаски', 'животн', 'попугай']):
            return 'Найдено животное'
        return 'Найдена вещь'
    if 'потеря' in lower or 'пропал' in lower or 'убежал' in lower or 'утерян' in lower:
        if any(w in lower for w in ['собак', 'кот', 'кош', 'щенок', 'пес', 'хаски', 'животн', 'попугай']):
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

def scrape_vk_public(group: dict) -> list[dict]:
    """Скрапинг публичной стены VK паблика."""
    items = []
    url = f"https://m.vk.com/{group['domain']}"
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

        posts = re.findall(r'<div class="pi_text">(.*?)</div>', html, re.DOTALL)
        # Only wall photos ( VK CDN images), skip avatars/icons by looking inside each post's own block
        wall_blocks = re.findall(r'<div class="wi_body[^"]*".*?(?=<div class="wi_body|</body>)', html, re.DOTALL)

        for idx, ptext in enumerate(posts[:5]):
            clean_p = re.sub(r'<[^>]+>', ' ', ptext).strip()
            if len(clean_p) < 15:
                continue
            cat = detect_category(clean_p, group["default_cat"])
            geo = geocode_nv_text(clean_p)
            first_line = clean_p.split('.')[0] if '.' in clean_p else clean_p[:60]

            # Prefer photos found inside the matching wall block; fall back to global index
            photo = None
            if idx < len(wall_blocks):
                m = re.search(r'src="(https://[^\s"]+?(?:userapi|vk)\.com[^\s"]*?(?:\.jpg|\.png|\.jpeg)[^\s"]*)"', wall_blocks[idx])
                if m:
                    photo = m.group(1)
            if photo is None:
                imgs = re.findall(r'src="(https://[^\s"]+?(?:userapi|vk)\.com[^\s"]*?(?:\.jpg|\.png|\.jpeg)[^\s"]*)"', html)
                photo = imgs[idx] if idx < len(imgs) else None

            items.append({
                "title": first_line[:150],
                "description": clean_p,
                "category": cat,
                "address": geo["address"],
                "lat": geo["lat"],
                "lng": geo["lng"],
                "photo_url": photo,
                "source": f"vk:{group['domain']}",
                "telegram_channel": group["name"]
            })
    except Exception as e:
        print(f"[VK SCRAPER] Не удалось загрузить {group['domain']}: {e}")
        
    return items

def run_vk_scraper(save_db=True) -> int:
    print("\n--- [VK SCRAPER] Запуск сканирования VK пабликов ---")
    all_parsed = []
    for grp in VK_PUBLIC_GROUPS:
        res = scrape_vk_public(grp)
        print(f"  Паблик VK '{grp['name']}': получено {len(res)} сообщений.")
        all_parsed.extend(res)
        
    if not save_db or not all_parsed:
        return len(all_parsed)
        
    saved = 0
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        db = SessionLocal()
        
        for item in all_parsed:
            h = hash_text(f"{item['title']}:{item['description']}")
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
        print(f"[VK SCRAPER SUCCESS] Сохранено {saved} новых объявлений из VK в базу данных.")
    except Exception as e:
        db.rollback()
        print(f"[VK SCRAPER ERROR] Ошибка записи в БД: {e}")
    finally:
        db.close()

    return saved

if __name__ == "__main__":
    run_vk_scraper(save_db=True)
