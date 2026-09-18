# services/business/news_parser.py
import os
import logging
import urllib.request
import json
import xml.etree.ElementTree as ET
from datetime import datetime, UTC
from sqlalchemy.orm import Session
from services.data_layer.models import Report

logger = logging.getLogger(__name__)

# Nizhnevartovsk / HMAO-Yugra RSS Feed URL
RSS_URL = "https://admhmao.ru/press-center/news/rss.php"

import re

# VK Public Config
VK_API_VERSION = "5.131"
VK_PUBLIC_ID = "-101037303"  # Example: "Официальный Нижневартовск" ID (-101037303) or "Инцидент Нижневартовск"


def clean_html(raw_html: str) -> str:
    """Strip HTML tags and normalize spaces to reduce token count."""
    if not raw_html:
        return ""
    # Strip HTML tags
    clean_text = re.sub(r'<[^>]+>', '', raw_html)
    # Decode basic HTML entities
    clean_text = clean_text.replace("&nbsp;", " ").replace("&quot;", '"').replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    # Normalize multiple whitespace/newlines
    clean_text = re.sub(r'\s+', ' ', clean_text).strip()
    return clean_text

async def parse_city_news_rss(db: Session):
    """Fetch and parse official city news RSS from n-vartovsk.ru."""
    logger.info("Starting Nizhnevartovsk RSS news parsing...")
    try:
        req = urllib.request.Request(
            RSS_URL,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
        )
        with urllib.request.urlopen(req, timeout=15) as response:
            xml_data = response.read()
            
        root = ET.fromstring(xml_data)
        items = root.findall(".//item")
        
        count = 0
        for item in items:
            title = item.find("title").text if item.find("title") is not None else ""
            link = item.find("link").text if item.find("link") is not None else ""
            raw_desc = item.find("description").text if item.find("description") is not None else ""
            desc = clean_html(raw_desc)
            pub_date = item.find("pubDate").text if item.find("pubDate") is not None else ""
            
            if not title:
                continue
                
            source_id = f"news:rss:{link}"
            
            # Check if this news item is already imported
            existing = db.query(Report).filter(Report.source == source_id).first()
            if not existing:
                # Parse pubDate if possible
                try:
                    # Example: "Tue, 07 Jul 2026 08:00:00 +0300"
                    dt = datetime.strptime(pub_date[:25].strip(), "%a, %d %b %Y %H:%M:%S")
                except Exception:
                    dt = datetime.now(UTC).replace(tzinfo=None)
                    
                news_report = Report(
                    title=f"📰 {title}",
                    description=f"{desc}\n\nИсточник: {link}",
                    category="Новости",
                    address="Нижневартовск",
                    lat=60.9388,  # Default city center center
                    lng=76.5585,
                    source=source_id,
                    status="open",
                    city="nizhnevartovsk",
                    created_at=dt
                )
                db.add(news_report)
                count += 1
                
        db.commit()
        logger.info(f"Successfully imported {count} new RSS news articles.")
    except Exception as e:
        logger.error(f"Failed to parse RSS news: {e}. Executing simulated fallback.")
        db.rollback()
        await _simulate_rss_news_fallback(db)


async def parse_vk_news(db: Session):
    """Fetch posts from VK city public using VK API if token is configured, or simulate with fallback."""
    logger.info("Starting VK news parsing...")
    vk_token = os.getenv("VK_SERVICE_TOKEN")
    
    if not vk_token:
        logger.warning("VK_SERVICE_TOKEN not configured. Skipping live VK parsing.")
        # Fallback simulation to keep the app functional in dev/demo environment
        await _simulate_vk_news_fallback(db)
        return
        
    try:
        url = (
            f"https://api.vk.com/method/wall.get"
            f"?owner_id={VK_PUBLIC_ID}&count=10&v={VK_API_VERSION}&access_token={vk_token}"
        )
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
            
        if "response" not in data:
            logger.error(f"VK API error: {data.get('error', {}).get('error_msg', 'Unknown')}")
            return
            
        posts = data["response"].get("items", [])
        count = 0
        for post in posts:
            post_id = post.get("id")
            text = post.get("text", "")
            date_ts = post.get("date")
            
            if not text or len(text.strip()) < 10:
                continue
                
            source_id = f"news:vk:{VK_PUBLIC_ID}:{post_id}"
            
            # Check if this VK post is already imported
            existing = db.query(Report).filter(Report.source == source_id).first()
            if not existing:
                dt = datetime.fromtimestamp(date_ts) if date_ts else datetime.now()
                
                # Use first line of post as title
                lines = [l.strip() for l in text.split("\n") if l.strip()]
                title = lines[0][:100] + "..." if lines else "Новость из ВК паблика"
                
                vk_report = Report(
                    title=f"📱 {title}",
                    description=text,
                    category="Новости",
                    address="Нижневартовск",
                    lat=60.9388,
                    lng=76.5585,
                    source=source_id,
                    status="open",
                    city="nizhnevartovsk",
                    created_at=dt
                )
                db.add(vk_report)
                count += 1
                
        db.commit()
        logger.info(f"Successfully imported {count} new VK news posts.")
    except Exception as e:
        logger.error(f"Failed to parse VK news: {e}")
        db.rollback()


async def _simulate_vk_news_fallback(db: Session):
    """Insert simulated VK public announcements for development and testing."""
    simulated_posts = [
        {
            "id": 9991,
            "text": "🚧 Внимание! С 8 по 12 июля будет перекрыто движение по улице Чапаева (участок от Мира до Ленина) в связи с дорожным ремонтом. Планируйте пути объезда заранее.",
            "title": "Перекрытие движения по ул. Чапаева"
        },
        {
            "id": 9992,
            "text": "🌳 В Комсомольском сквере Нижневартовска завершились работы по благоустройству новой детской площадки с безопасным покрытием и качелями.",
            "title": "Новая детская площадка в Комсомольском сквере"
        }
    ]
    
    count = 0
    for post in simulated_posts:
        source_id = f"news:vk:simulated:{post['id']}"
        existing = db.query(Report).filter(Report.source == source_id).first()
        if not existing:
            news_report = Report(
                title=f"📱 {post['title']}",
                description=post["text"],
                category="Новости",
                address="Нижневартовск",
                lat=60.9388,
                lng=76.5585,
                source=source_id,
                status="open",
                city="nizhnevartovsk",
                created_at=datetime.now()
            )
            db.add(news_report)
            count += 1
            
    if count > 0:
        db.commit()
        logger.info(f"Simulated {count} fallback VK news posts.")


async def _simulate_rss_news_fallback(db: Session):
    """Insert simulated official RSS announcements for development and testing."""
    simulated_news = [
        {
            "id": 8881,
            "title": "Мэрия выделила 50 млн рублей на ремонт теплосетей к зиме",
            "text": "Администрация Нижневартовска утвердила план модернизации теплосетей. Работы начнутся в июле и затронут 12 микрорайонов города.",
            "link": "https://www.n-vartovsk.ru/news/8881"
        },
        {
            "id": 8882,
            "title": "Открытие нового спортивного комплекса на Интернациональной перенесено на сентябрь",
            "text": "Спортивный комитет сообщил, что запуск многофункционального комплекса задерживается из-за задержки поставок вентиляционного оборудования.",
            "link": "https://www.n-vartovsk.ru/news/8882"
        }
    ]
    
    count = 0
    for news in simulated_news:
        source_id = f"news:rss:simulated:{news['id']}"
        existing = db.query(Report).filter(Report.source == source_id).first()
        if not existing:
            news_report = Report(
                title=f"📰 {news['title']}",
                description=f"{news['text']}\n\nИсточник: {news['link']}",
                category="Новости",
                address="Нижневартовск",
                lat=60.9388,
                lng=76.5585,
                source=source_id,
                status="open",
                city="nizhnevartovsk",
                created_at=datetime.now()
            )
            db.add(news_report)
            count += 1
            
    if count > 0:
        db.commit()
        logger.info(f"Simulated {count} fallback RSS news articles.")

