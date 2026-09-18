#!/usr/bin/env python3
"""
Backfill VK wall posts from the last 24 hours.
Processes them using the standard pipeline to insert them into the DB.
"""

import asyncio
import os
import sys
from datetime import datetime, timedelta, UTC
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

import logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
logger = logging.getLogger("backfill_vk_today")

from services.monitoring.vk_monitor_service import (
    VK_GROUPS,
    fetch_group_wall,
    extract_post_text,
    extract_vk_photos,
    build_vk_post_link,
)
from services.monitoring.vk_handler import handle_vk_complaint
from services.zai_service import analyze_complaint
from services.monitoring.filters import is_ad_or_spam, is_relevant_message

async def main():
    logger.info("Starting VK backfill for the last 24 hours...")
    
    # Calculate cutoff time: 24 hours ago
    cutoff_time = datetime.now(UTC) - timedelta(hours=24)
    logger.info("Cutoff time (UTC): %s", cutoff_time.isoformat())
    
    scanned = 0
    saved = 0
    
    for short_name, group_id, name in VK_GROUPS:
        # Skip non-Nizhnevartovsk groups to focus on Nizhnevartovsk complaints
        if "Новосибирск" in name or "act54" in short_name or "incident_nsk" in short_name:
            continue
            
        logger.info("Checking VK group: %s (id: %s)...", name, group_id)
        try:
            posts = await fetch_group_wall(group_id, count=15)
            for post in posts:
                post_id = post.get("id", 0)
                post_date = datetime.fromtimestamp(post.get("date", 0), UTC)
                
                if post_date < cutoff_time:
                    continue
                
                scanned += 1
                text = extract_post_text(post)
                if not text or len(text) < 20:
                    continue
                
                # Check for ads
                if is_ad_or_spam(text):
                    continue
                
                # Analyze via AI
                logger.info("Analyzing post %d from %s...", post_id, name)
                analysis = await analyze_complaint(text)
                category = analysis.get("category", "Прочее")
                
                # Check relevance
                if not is_relevant_message(text, category):
                    continue
                
                photos = extract_vk_photos(post)
                post_link = build_vk_post_link(group_id, post_id)
                
                complaint_data = {
                    "text": text,
                    "category": category,
                    "address": analysis.get("address"),
                    "summary": analysis.get("description") or text[:120],
                    "title": analysis.get("title") or text[:60],
                    "provider": analysis.get("provider", "zai"),
                    "source": f"vk:{group_id}",
                    "source_name": name,
                    "post_link": post_link,
                    "photos": photos,
                    "post_id": post_id,
                    "location_hints": analysis.get("address"),
                }
                
                # Trigger handle_vk_complaint
                await handle_vk_complaint(None, complaint_data)
                saved += 1
            
            # Rate limit sleep
            await asyncio.sleep(1.0)
        except Exception as e:
            logger.error("Error backfilling group %s: %s", name, e, exc_info=True)
            
    logger.info("VK Backfill completed. Scanned: %d, Saved: %d", scanned, saved)

if __name__ == "__main__":
    asyncio.run(main())
