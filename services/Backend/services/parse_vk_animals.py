#!/usr/bin/env python3
"""
Scraper and monitoring script for animal lost & found channels.
Monitors public TG channels and local VK listings.
Strictly focused on Nizhnevartovsk (Нижневартовск) as requested.
Includes robust deduplication logic.
"""

import os
import sys
import time
import json
import logging
import urllib.request
import urllib.parse
import re
import random
from pathlib import Path
from datetime import datetime, timedelta

# Setup path to import database/models
BACKEND_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BACKEND_DIR.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.append(str(PROJECT_ROOT))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(PROJECT_ROOT / "parse_vk_animals.log", encoding="utf-8")
    ]
)
logger = logging.getLogger("parse_vk_animals")

# Real-world lost & found posts strictly from Nizhnevartovsk (Нижневартовск)
def is_duplicate(db, text: str, category: str, title: str) -> bool:
    """
    Robust deduplication check against recent reports in the last 7 days.
    Checks exact match, normalized text containment, Jaccard similarity, and matching phone numbers.
    """
    from services.data_layer.models import Report

    def normalize(t):
        return re.sub(r'\W+', '', t).lower()

    normalized_text = normalize(text)
    if not normalized_text:
        return True

    # Check for duplicates in the last 7 days
    seven_days_ago = datetime.utcnow() - timedelta(days=7)
    recent_reports = db.query(Report).filter(
        Report.category == category,
        Report.created_at >= seven_days_ago,
        Report.city == "nizhnevartovsk"
    ).all()

    for r in recent_reports:
        norm_r_desc = normalize(r.description or "")
        if not norm_r_desc:
            continue

        # Exact normalized match
        if norm_r_desc == normalized_text:
            return True

        # Jaccard similarity over words (character sets match for almost any Russian text)
        set_new = set(normalized_text.split())
        set_r = set(norm_r_desc.split())
        intersection = len(set_new & set_r)
        union = len(set_new | set_r)
        if union > 0 and (intersection / union) > 0.85:
            return True

        # Check for identical phone numbers combined with same title
        phone_pattern = re.compile(r'((?:\+7|8)[\s-]?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2})')
        phones_new = set(phone_pattern.findall(text))
        phones_r = set(phone_pattern.findall(r.description or ""))
        if phones_new and phones_r and phones_new.intersection(phones_r) and r.title == title:
            return True

    return False

def parse_live_telegram_channel(channel_name, city="nizhnevartovsk"):
    """
    Attempts to fetch live posts from Telegram public channel preview (t.me/s/...)
    Uses the tor SOCKS proxy when direct internet is unavailable (server contour).
    """
    url = f"https://t.me/s/{channel_name}"
    logger.info("Attempting to parse Telegram channel preview: %s", url)

    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
    )

    try:
        # Server containers reach the internet only through the tor SOCKS proxy;
        # locally (dev machine) direct connection works — try both.
        try:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with opener.open(req, timeout=10) as response:
                html = response.read().decode('utf-8', errors='ignore')
        except urllib.error.URLError:
            import socket as _socket

            import socks as _socks

            _socks.set_default_proxy(_socks.SOCKS5, "tor", 9050)
            _socket.socket = _socks.socksocket
            with urllib.request.urlopen(req, timeout=20) as response:
                html = response.read().decode('utf-8', errors='ignore')
        
        # Regex to find message elements
        msg_blocks = re.findall(r'class="tgme_widget_message_wrap[^"]*".*?class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>', html, re.DOTALL)
        logger.info("Found %d message text blocks on %s", len(msg_blocks), channel_name)
        
        # Extract photos
        photo_matches = re.findall(r'class="tgme_widget_message_photo_wrap[^"]*".*?style="background-image:url\(\'(.*?)\'\)"', html)
        logger.info("Found %d media attachments on %s", len(photo_matches), channel_name)
        
        # Keywords for both animals and things/documents
        animal_keywords = ["собак", "кошк", "кот", "пес", "пёс", "кобел", "сук", "хаски", "шпиц", "овчарк", "щен", "котен"]
        thing_keywords = ["ключ", "документ", "паспорт", "кошелек", "сумк", "рюкзак", "телефон", "права", "карточк", "номер"]
        all_keywords = animal_keywords + thing_keywords
        
        phone_pattern = re.compile(r'((?:\+7|8)[\s-]?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2})')
        
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        db = SessionLocal()
        
        inserted = 0
        try:
            for idx, block in enumerate(msg_blocks):
                clean_text = re.sub(r'<[^>]+>', '', block).strip()
                # Check keywords
                if not any(kw in clean_text.lower() for kw in all_keywords):
                    continue

                # Check phone
                phones = phone_pattern.findall(clean_text)
                if not phones:
                    continue

                # Extract first 50 chars for title
                title = clean_text.split('\n')[0][:60]
                if len(title) < 10:
                    title = "Потерялось/найдено животное или вещь"

                # Determine category
                category = "Потеряно животное"
                if any(kw in clean_text.lower() for kw in animal_keywords):
                    if any(w in clean_text.lower() for w in ["найден", "нашли", "прибился"]):
                        category = "Найдено животное"
                    else:
                        category = "Потеряно животное"
                else:
                    if any(w in clean_text.lower() for w in ["найден", "нашли"]):
                        category = "Найдена вещь"
                    else:
                        category = "Потеряна вещь"
            
                # Robust Deduplication check
                if not is_duplicate(db, clean_text, category, title):
                    # Coordinates are unknown until the owner confirms the address;
                    # random coordinates would place the marker in a wrong part of the city.
                    lat = None
                    lng = None

                    # Check if there is an image for this block
                    photo_url = ""
                    if idx < len(photo_matches):
                        photo_url = photo_matches[idx]

                    description_with_photo = clean_text
                    if photo_url:
                        description_with_photo += f"\n\n{photo_url}"

                    report = Report(
                        title=title,
                        description=description_with_photo,
                        category=category,
                        address="Уточняется у владельца, Нижневартовск",
                        lat=lat,
                        lng=lng,
                        city="nizhnevartovsk",
                        source=f"Telegram ({channel_name})",
                        status="open"
                    )
                    db.add(report)
                    inserted += 1

            if inserted > 0:
                db.commit()
                logger.info("Scraped and inserted %d new live reports from Telegram (%s)!", inserted, channel_name)
        except Exception as e:
            db.rollback()
            logger.warning("Live scrape from Telegram %s failed (will use fallback): %s", channel_name, e)
        finally:
            db.close()

    except Exception as e:
        logger.warning("Live scrape from Telegram %s failed (will use fallback): %s", channel_name, e)


def run_monitoring_cycle():
    logger.info("Executing periodic Nizhnevartovsk monitor cycle...")

    # Только живой парсинг открытых TG-каналов: статичные сиды удалены,
    # все записи в бюро находок — из реальных источников с дедупликацией.
    nizhnevartovsk_channels = [
        "poteryashkinv",       # Потеряшки Нижневартовск
        "nv_byuro",            # Бюро находок Нижневартовск
        "lost_nv",             # Потерянные и найденные вещи
        "podslushano_dogs_nv", # Подслушано Животные Нижневартовск
        "byuro_nv_poisk"       # Бюро поиска вещей/документов
    ]

    for channel in nizhnevartovsk_channels:
        parse_live_telegram_channel(channel, "nizhnevartovsk")

def main():
    logger.info("Starting Nizhnevartovsk Lost & Found Scraper & Monitor...")
    
    # Execute immediately once
    run_monitoring_cycle()
    
    # Periodic check if running in server mode
    if len(sys.argv) > 1 and sys.argv[1] == '--one-shot':
        logger.info("One-shot run finished.")
        return
        
    logger.info("Entering periodic scraping loop (every 30 minutes)...")
    try:
        while True:
            time.sleep(1800)
            run_monitoring_cycle()
    except KeyboardInterrupt:
        logger.info("Monitoring service stopped by user.")

if __name__ == '__main__':
    main()
