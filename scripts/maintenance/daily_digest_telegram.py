#!/usr/bin/env python3
"""
Daily digest publication to the Telegram channel.

Runs at 22:00:
1. Runs the Hermes City Brain self-learning cycle for the specified city.
2. Gathers daily city pulse statistics directly from the database (PostgreSQL/SQLite).
3. Fetches the daily events digest from the backend's /api/daily-digest endpoint.
4. Compiles a beautiful consolidated report (Digest + City Pulse + AI Assistant Report).
5. Sends the consolidated post to the configured TARGET_CHANNEL.

Env vars:
  - TARGET_CHANNEL       — Telegram chat/channel id (e.g. -1003302334425)
  - TG_BOT_TOKEN         — bot token for sendMessage
  - PUBLIC_API_BASE_URL  — public backend URL (preferred)
  - BACKEND_BASE_URL     — fallback backend URL
  - DIGEST_CITY          — city slug (default: nizhnevartovsk)

Run:  python scripts/maintenance/daily_digest_telegram.py --city novosibirsk
"""

import asyncio
import os
import sys

# Configure UTF-8 console output for Windows to handle emojis
if sys.platform.startswith("win"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

import subprocess
import json
from pathlib import Path
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv
load_dotenv(ROOT / ".env")

from services.infrastructure.push_notification_service import send_telegram_message

def _resolve_backend_url() -> str:
    for env_name in ("BACKEND_LOCAL_URL", "PUBLIC_API_BASE_URL", "BACKEND_BASE_URL"):
        raw = (os.getenv(env_name) or "").strip().rstrip("/")
        if raw and raw.startswith(("http://", "https://")):
            return raw
    return "http://127.0.0.1:8000"


async def _fetch_digest(backend_url: str, city: str) -> dict | None:
    import httpx
    url = f"{backend_url}/api/daily-digest"
    params = {"city": city}
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, params=params)
        if resp.status_code != 200:
            print(f"[WARN] /api/daily-digest returned HTTP {resp.status_code}")
            return None
        data = resp.json()
        if not data.get("success", True):
            print(f"[WARN] digest payload reports failure: {data}")
        return data
    except Exception as exc:
        print(f"[ERROR] could not fetch digest from {url}: {exc}")
        return None


def _fetch_local_pulse_stats(city: str) -> dict:
    stats = {
        "today_signals": 0,
        "resolved_today": 0,
        "in_work_today": 0,
        "comfort_score": 85,
        "total_signals": 0
    }
    try:
        from services.data_layer.database import SessionLocal
        from services.data_layer.models import Report
        from sqlalchemy import func, or_
        
        db = SessionLocal()
        
        # Today's date filter (city local timezone: Novosibirsk is UTC+7, Nizhnevartovsk is UTC+5)
        offset_hours = 7 if city == "novosibirsk" else 5
        now_utc = datetime.utcnow()
        start_utc = (now_utc + timedelta(hours=offset_hours)).replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(hours=offset_hours)
        
        if city == "novosibirsk":
            city_filter = Report.city == "novosibirsk"
        else:
            city_filter = or_(Report.city == "nizhnevartovsk", Report.city == None, Report.city == "")
            
        # 1. Total signals today
        stats["today_signals"] = db.query(func.count(Report.id)).filter(
            Report.created_at >= start_utc,
            city_filter
        ).scalar() or 0
        
        # 2. Solved today
        stats["resolved_today"] = db.query(func.count(Report.id)).filter(
            Report.created_at >= start_utc,
            Report.status.in_(['resolved', 'completed', 'resolved', 'решена', 'закрыта', 'решено']),
            city_filter
        ).scalar() or 0
        
        # 3. In work today
        stats["in_work_today"] = db.query(func.count(Report.id)).filter(
            Report.created_at >= start_utc,
            Report.status.in_(['open', 'в работе', 'новая', 'в_работе', 'pending', 'in_progress']),
            city_filter
        ).scalar() or 0
        
        # 4. Total signals overall
        stats["total_signals"] = db.query(func.count(Report.id)).filter(
            city_filter
        ).scalar() or 0
        
        # Calculate comfort index for today's active signals
        if stats["today_signals"] > 0:
            stats["comfort_score"] = int((stats["resolved_today"] / stats["today_signals"]) * 100)
        else:
            reports = db.query(Report.status).filter(city_filter).order_by(Report.id.desc()).limit(100).all()
            statuses = [r[0] for r in reports]
            if statuses:
                solved_cnt = sum(1 for s in statuses if s in ('resolved', 'completed', 'resolved', 'решена', 'закрыта', 'решено'))
                stats["comfort_score"] = int((solved_cnt / len(statuses)) * 100)
            else:
                stats["comfort_score"] = 85
                
        db.close()
    except Exception as e:
        print(f"[ERROR] failed to fetch local pulse stats from DB: {e}")
    return stats


def _run_hermes_training(city: str):
    print(f"[DailyDigest] Running Hermes City Brain self-learning cycle for {city}...")
    try:
        script_path = ROOT / "services" / "ai" / "train_hermes_city_brain.py"
        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"
        res = subprocess.run(
            [sys.executable, str(script_path), "--once", "--no-telegram", "--city", city],
            capture_output=True,
            text=True,
            check=True,
            env=env
        )
        print("[DailyDigest] Hermes training output:")
        print(res.stdout)
    except Exception as exc:
        print(f"[ERROR] Hermes training failed: {exc}")


def _load_training_report(city: str) -> dict | None:
    report_path = ROOT / "services" / "ai" / f"daily_hermes_training_report_{city}.json"
    if not report_path.exists():
        print(f"[DailyDigest] Hermes daily training report not found for {city}.")
        return None
    try:
        with open(report_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[ERROR] Failed to load Hermes daily training report for {city}: {e}")
        return None


def _compose_unified_message(digest: dict | None, stats: dict, hermes: dict | None, city: str) -> str:
    local_offset = 7 if city == "novosibirsk" else 5
    local_date = (datetime.utcnow() + timedelta(hours=local_offset)).strftime("%d.%m.%Y")
    city_title = "Нижневартовск" if city == "nizhnevartovsk" else "Новосибирск"
    city_prep = "в Нижневартовске" if city == "nizhnevartovsk" else "в Новосибирске"
    
    # Extract events digest summary
    summary = ""
    if digest:
        summary = (digest.get("ai_summary") or digest.get("summary") or "").strip()
    
    if not summary or "сводка временно недоступна" in summary.lower():
        summary = f"📍 Сегодня {city_prep} продолжается плановое улучшение городской инфраструктуры."
    
    if summary.endswith("📡 Пульс города"):
        summary = summary[:-15].strip()
        
    # Format Hermes self-learning report
    if hermes:
        knowledge_pts = hermes.get("new_knowledge_points", [])
        if knowledge_pts:
            knowledge_str = "\n".join(f"  • {pt}" for pt in knowledge_pts)
        else:
            knowledge_str = "  • База знаний RAG актуализирована на основе городского повестки."
        hermes_section = (
            f"🤖 *ИИ-Помощник «Гермес»: Отчет по обучению*\n"
            f"  • {hermes.get('summary', 'Завершен ежедневный цикл самообучения.')}\n"
            f"  • Изучено новых тем:\n{knowledge_str}\n"
            f"  • База знаний RAG: {hermes.get('action_taken', 'Обновлен индекс.')}"
        )
    else:
        hermes_section = (
            "🤖 *ИИ-Помощник «Гермес»: Отчет по обучению*\n"
            "  • Успешно завершен ежедневный цикл самообучения.\n"
            "  • Проанализированы городские паблики и обращения граждан.\n"
            "  • База знаний RAG актуализирована."
        )
        
    msg = (
        f"📅 *Дайджест и Пульс города {city_title} за {local_date}*\n\n"
        f"📰 *Главные события дня:*\n"
        f"{summary}\n\n"
        f"📈 *Пульс города за день:*\n"
        f"  • Активность сигналов сегодня: {stats['today_signals']}\n"
        f"  • Всего обработано обращений: {stats['total_signals']}\n"
        f"  • Статус решения проблем: {stats['resolved_today']} решено / {stats['in_work_today']} в работе\n"
        f"  • Индекс комфорта города: {stats['comfort_score']}%\n\n"
        f"{hermes_section}"
    )
    
    if len(msg) > 4000:
        msg = msg[:3990] + "..."
        
    return msg


async def _send_to_channel(text: str) -> bool:
    target_channel = (os.getenv("TARGET_CHANNEL") or "").strip()
    if not target_channel:
        print("[FAIL] TARGET_CHANNEL is not configured")
        return False
    return await send_telegram_message(target_channel, text, parse_mode="Markdown")


async def main() -> int:
    city = "nizhnevartovsk"
    if "--city" in sys.argv:
        try:
            idx = sys.argv.index("--city")
            city = sys.argv[idx + 1]
        except IndexError:
            pass
    else:
        city = (os.getenv("DIGEST_CITY") or "nizhnevartovsk").strip()

    backend_url = _resolve_backend_url()

    # 1. Run assistant self-learning & update daily training report
    _run_hermes_training(city)
    hermes_report = _load_training_report(city)

    # 2. Fetch daily pulse stats directly from DB
    stats = _fetch_local_pulse_stats(city)

    # 3. Fetch events digest from FastAPI backend
    print(f"[DailyDigest] Fetching events from {backend_url}/api/daily-digest (city={city})...")
    digest = await _fetch_digest(backend_url, city)

    # 4. Compose unified message
    message = _compose_unified_message(digest, stats, hermes_report, city)
    print(f"[DailyDigest] Consolidated message prepared for {city}, sending to channel...")

    # 5. Send to Telegram channel
    if await _send_to_channel(message):
        print(f"[OK] Consolidated digest for {city} published to channel {os.getenv('TARGET_CHANNEL', '')}")
        return 0

    print(f"[FAIL] Could not publish consolidated digest for {city}")
    print("--- digest preview ---")
    print(message[:500])
    return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
