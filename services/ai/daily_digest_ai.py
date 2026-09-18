"""
Daily AI Digest — ежедневный AI-анализ городских проблем.
Каждый день в 00:00 (UTC+5) генерирует сводку:
- Топ-3 категории за день
- Топ-5 проблемных улиц
- Общий sentiment (настроение)
- AI-генерированный вердикт по обстановке в городе
"""
import asyncio
import json
import logging
from collections import Counter
from datetime import datetime, timedelta, timezone
from typing import Any
logger = logging.getLogger(__name__)
# Timezone: UTC+5 (Нижневартовск)
NV_TZ = timezone(timedelta(hours=5))
async def generate_daily_digest(
    target_date: datetime | None = None,
    city: str = "nizhnevartovsk",
) -> dict[str, Any]:
    """Generate daily digest for the given date and city (defaults to yesterday, nizhnevartovsk).
    Returns dict with: date, total_reports, top_categories, top_streets,
    mood, ai_summary.
    """
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import Report
    if target_date is None:
        # Yesterday in NV timezone
        now_nv = datetime.now(NV_TZ)
        target_date = (now_nv - timedelta(days=1)).replace(
            hour=0, minute=0, second=0, microsecond=0, tzinfo=None
        )
    day_start = target_date.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    db = SessionLocal()
    try:
        from sqlalchemy import or_
        query = db.query(Report).filter(Report.created_at >= day_start, Report.created_at < day_end)
        # Приложение работает только с Нижневартовском
        query = query.filter(or_(Report.city == "nizhnevartovsk", Report.city == None, Report.city == ""))
        reports = query.all()
        if not reports:
            return {
                "date": day_start.isoformat(),
                "total_reports": 0,
                "top_categories": [],
                "top_streets": [],
                "mood": "спокойное",
                "ai_summary": "За прошедшие сутки городских проблем не зафиксировано.",
            }
        total = len(reports)
        # Top categories
        cat_counter = Counter(r.category for r in reports if r.category)
        top_categories = [
            {"category": cat, "count": cnt} for cat, cnt in cat_counter.most_common(5)
        ]
        # Top streets (extract street from address)
        import re
        street_counter: Counter = Counter()
        for r in reports:
            if not r.address:
                continue
            # Extract street name
            m = re.search(
                r"(?:ул\.?|улица|пр\.?|проспект)\s+([А-Яа-яЁё0-9\-\s]+?)(?:\s+\d|\s*,|$)",
                r.address,
                re.IGNORECASE,
            )
            if m:
                street = m.group(1).strip()
                if len(street) >= 3:
                    street_counter[street] += 1
        top_streets = [
            {"street": street, "count": cnt}
            for street, cnt in street_counter.most_common(5)
        ]
        # Sentiment analysis
        try:
            from services.ai.sentiment_service import get_city_mood
            texts = [
                r.description or r.title or ""
                for r in reports
                if r.description or r.title
            ]
            mood_data = await get_city_mood(texts[:100])  # Limit to 100 for performance
            mood = mood_data.get("mood", "нейтральное")
        except Exception as e:
            logger.warning("Sentiment analysis failed: %s", e)
            mood = "нейтральное"
        # AI summary generation
        ai_summary = await _generate_ai_summary(
            total, top_categories, top_streets, mood, day_start
        )
        digest = {
            "date": day_start.isoformat(),
            "total_reports": total,
            "top_categories": top_categories,
            "top_streets": top_streets,
            "mood": mood,
            "ai_summary": ai_summary,
        }
        # Save to DB
        await _save_digest_to_db(digest)
        return digest
    except Exception as e:
        logger.error("Daily digest generation failed: %s", e, exc_info=True)
        return {
            "date": day_start.isoformat(),
            "total_reports": 0,
            "top_categories": [],
            "top_streets": [],
            "mood": "нет данных",
            "ai_summary": f"Ошибка генерации дайджеста: {e}",
        }
    finally:
        db.close()
async def _generate_ai_summary(
    total: int,
    top_categories: list[dict],
    top_streets: list[dict],
    mood: str,
    date: datetime,
) -> str:
    """Generate a short AI summary of the day's city problems."""
    date_str = date.strftime("%d.%m.%Y")
    cats_str = ", ".join(f"{c['category']} ({c['count']})" for c in top_categories[:3])
    streets_str = ", ".join(f"{s['street']} ({s['count']})" for s in top_streets[:3])
    prompt = (
        f"Ты — городской аналитик Нижневартовска. Составь КРАТКУЮ сводку за {date_str}.\n\n"
        f"Данные:\n"
        f"- Всего проблем: {total}\n"
        f"- Топ категории: {cats_str or 'нет данных'}\n"
        f"- Проблемные улицы: {streets_str or 'нет данных'}\n\n"
        f"Напиши 2-3 предложения для бегущей строки в приложении. "
        f"Стиль: информационный, без паники, объективный. "
        f"Начни с общей оценки обстановки."
    )
    try:
        from services.ai.zai_service import (
            LITELLM_MASTER_KEY,
            LITELLM_TEXT_MODEL,
            LITELLM_URLS,
            _call_ai_api,
        )
        payload = {
            "model": LITELLM_TEXT_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.3,
            "max_tokens": 200,
            "stream": False,
        }
        headers = {"Content-Type": "application/json"}
        if LITELLM_MASTER_KEY:
            headers["Authorization"] = f"Bearer {LITELLM_MASTER_KEY}"
        for base_url in LITELLM_URLS:
            content = await _call_ai_api(
                f"{base_url}/chat/completions",
                payload,
                headers,
                "DailyDigest",
                timeout=30.0,
            )
            if content:
                # Clean up the response
                content = content.strip().strip('"').strip()
                if len(content) > 20:
                    return content
    except Exception as e:
        logger.warning("AI summary generation failed: %s", e)
    # Fallback: generate without AI
    if total == 0:
        return (
            f"За {date_str} городских проблем не зафиксировано. Обстановка спокойная."
        )
    summary = f"За {date_str} зафиксировано {total} городских проблем. "
    if top_categories:
        summary += f"Основные: {cats_str}. "
    return summary
async def _save_digest_to_db(digest: dict[str, Any]) -> None:
    """Save digest to the DailyDigest table."""
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import DailyDigest
    db = SessionLocal()
    try:
        date_val = datetime.fromisoformat(digest["date"])
        existing = db.query(DailyDigest).filter(DailyDigest.date == date_val).first()
        if existing:
            existing.total_reports = digest["total_reports"]
            existing.top_categories = json.dumps(digest["top_categories"], ensure_ascii=False)
            existing.top_streets = json.dumps(digest["top_streets"], ensure_ascii=False)
            existing.mood = digest["mood"]
            existing.ai_summary = digest["ai_summary"]
        else:
            record = DailyDigest(
                date=date_val,
                total_reports=digest["total_reports"],
                top_categories=json.dumps(digest["top_categories"], ensure_ascii=False),
                top_streets=json.dumps(digest["top_streets"], ensure_ascii=False),
                mood=digest["mood"],
                ai_summary=digest["ai_summary"],
            )
            db.add(record)
        db.commit()
        logger.info("Daily digest saved for %s", digest["date"])
    except Exception as e:
        logger.error("Failed to save daily digest: %s", e)
        db.rollback()
    finally:
        db.close()
async def get_latest_digest() -> dict[str, Any] | None:
    """Get the most recent daily digest."""
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import DailyDigest
    db = SessionLocal()
    try:
        record = db.query(DailyDigest).order_by(DailyDigest.date.desc()).first()
        if not record:
            return None
        return {
            "date": record.date.isoformat() if record.date else None,
            "total_reports": record.total_reports,
            "top_categories": json.loads(record.top_categories or "[]"),
            "top_streets": json.loads(record.top_streets or "[]"),
            "mood": record.mood,
            "ai_summary": record.ai_summary,
        }
    except Exception as e:
        logger.error("Failed to get latest digest: %s", e)
        return None
    finally:
        db.close()
async def get_digest_history(days: int = 7) -> list[dict[str, Any]]:
    """Get digest history for the last N days."""
    from services.data_layer.database import SessionLocal
    from services.data_layer.models import DailyDigest
    db = SessionLocal()
    try:
        records = (
            db.query(DailyDigest).order_by(DailyDigest.date.desc()).limit(days).all()
        )
        return [
            {
                "date": r.date.isoformat() if r.date else None,
                "total_reports": r.total_reports,
                "top_categories": json.loads(r.top_categories or "[]"),
                "top_streets": json.loads(r.top_streets or "[]"),
                "mood": r.mood,
                "ai_summary": r.ai_summary,
            }
            for r in records
        ]
    except Exception as e:
        logger.error("Failed to get digest history: %s", e)
        return []
    finally:
        db.close()
async def publish_digest_to_telegram(client, digest, city: str = "nizhnevartovsk") -> None:
    """Publish formatted digest to @monitornv/channel."""
    try:
        from services.monitoring.config import TARGET_CHANNEL
        total_reports = digest.get("total_reports", 0)
        date_str = ""
        if digest.get("date"):
            try:
                date_str = datetime.fromisoformat(digest["date"]).strftime("%d.%m.%Y")
            except Exception:
                date_str = str(digest["date"])[:10]
        else:
            date_str = datetime.now(NV_TZ).strftime("%d.%m.%Y")
        cats_str = ""
        if digest.get("top_categories"):
            cats_str = "\n".join(
                f"  • {c['category']}: {c['count']}" for c in digest["top_categories"][:3]
            )
        streets_str = ""
        if digest.get("top_streets"):
            streets_str = "\n".join(
                f"  • ул. {s['street']}: {s['count']}" for s in digest["top_streets"][:3]
            )
        city_title = "Нижневартовск"
        msg_parts = [
            f"📊 <b>Дайджест дня ({city_title}) за {date_str}</b>",
            "",
            f"🏙️ <b>Общая статистика:</b>",
            f"📍 Новых сигналов от жителей: {total_reports}",
            f"🎭 Общее настроение: {digest.get('mood', 'нейтральное')}",
            ""
        ]
        if cats_str:
            msg_parts.extend([
                "🗂️ <b>Топ категорий:</b>",
                cats_str,
                ""
            ])
        if streets_str:
            msg_parts.extend([
                "🗺️ <b>Проблемные улицы:</b>",
                streets_str,
                ""
            ])
        hashtag = "#Нижневартовск"
        msg_parts.extend([
            "🤖 <b>AI-анализ обстановки:</b>",
            digest.get("ai_summary", "Сводка формируется..."),
            "",
            f"#Дайджест {hashtag}"
        ])
        msg_text = "\n".join(msg_parts)
        await client.send_message(TARGET_CHANNEL, msg_text, parse_mode="html")
        logger.info("📊 Daily digest for %s successfully published to channel", city)
    except Exception as e:
        logger.error("Failed to publish daily digest to Telegram for %s: %s", city, e)
async def digest_scheduler(client=None):
    """Background scheduler: runs digest generation hourly NV time for both cities."""
    logger.info("📊 Daily digest scheduler started (UTC+5, hourly at minute :05) for Nizhnevartovsk")
    # Run once immediately on startup
    try:
        logger.info("📊 Run-on-startup: Generating/updating today's digest...")
        today_start = datetime.now(NV_TZ).replace(
            hour=0, minute=0, second=0, microsecond=0, tzinfo=None
        )
        for city in ["nizhnevartovsk"]:
            logger.info("📊 Run-on-startup: Generating/updating today's digest for %s...", city)
            digest = await generate_daily_digest(target_date=today_start, city=city)
            # On startup, also publish yesterday's final digest if client is available
            if client:
                yesterday_start = today_start - timedelta(days=1)
                logger.info("📊 Run-on-startup: Generating/publishing yesterday's final digest for %s...", city)
                yesterday_digest = await generate_daily_digest(target_date=yesterday_start, city=city)
                await publish_digest_to_telegram(client, yesterday_digest, city=city)
    except Exception as e:
        logger.error("Error on startup digest run: %s", e)
    while True:
        try:
            now_nv = datetime.now(NV_TZ)
            # Calculate next hourly run at minute 5
            next_run = now_nv.replace(minute=5, second=0, microsecond=0)
            if now_nv >= next_run:
                next_run += timedelta(hours=1)
            wait_seconds = (next_run - now_nv).total_seconds()
            logger.info(
                "📊 Next digest run at %s (in %.0f min)",
                next_run.strftime("%H:%M:%S"),
                wait_seconds / 60,
            )
            await asyncio.sleep(wait_seconds)
            today_start = datetime.now(NV_TZ).replace(
                hour=0, minute=0, second=0, microsecond=0, tzinfo=None
            )
            for city in ["nizhnevartovsk"]:
                logger.info("📊 Generating and updating today's digest for %s...", city)
                digest = await generate_daily_digest(target_date=today_start, city=city)
                logger.info(
                    "📊 Today's digest updated for %s: %d reports, mood=%s",
                    city,
                    digest.get("total_reports", 0),
                    digest.get("mood", "?"),
                )
                # If it's the run at 00:05 (hour == 0), publish yesterday's final digest
                if client and datetime.now(NV_TZ).hour == 0:
                    yesterday_start = today_start - timedelta(days=1)
                    logger.info("📊 Publishing final daily digest for yesterday for %s...", city)
                    yesterday_digest = await generate_daily_digest(target_date=yesterday_start, city=city)
                    await publish_digest_to_telegram(client, yesterday_digest, city=city)
                # If it's the run at 22:05 (hour == 22), run Hermes self-learning and publish the training report
                if datetime.now(NV_TZ).hour == 22:
                    logger.info("📊 22:00 daily check: Triggering daily training and digest telegram publication for %s...", city)
                    try:
                        import subprocess
                        import sys
                        script_path = ROOT / "scripts" / "maintenance" / "daily_digest_telegram.py"
                        env = os.environ.copy()
                        env["PYTHONIOENCODING"] = "utf-8"
                        subprocess.Popen(
                            [sys.executable, str(script_path), "--city", city],
                            env=env
                        )
                        logger.info("📊 Subprocess triggered daily_digest_telegram.py for %s", city)
                    except Exception as sub_err:
                        logger.error("Failed to run daily_digest_telegram.py via scheduler: %s", sub_err)
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error("Digest scheduler error: %s", e, exc_info=True)
            await asyncio.sleep(300)  # Retry in 5 minutes on error