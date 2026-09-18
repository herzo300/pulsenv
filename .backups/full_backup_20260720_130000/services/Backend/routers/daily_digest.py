"""
Daily Digest AI summary — generates and serves daily city incident digests.
"""

import logging
import os
import re
from datetime import UTC, datetime, timedelta
from typing import Any

_EMERGENCY_KEYWORDS = re.compile(
    r"(?i)(чp|чрезвыч|эваку|пожар|взрыв|обруш|авар|утеч|газ|"
    r"шторм|ураган|смерч|сильн\w*\s+ветер|ветер\s+\d+|"
    r"голол|налед|метел|буран|мороз|замороз|"
    r"перекрыт|затоп|прорыв|без\s+света|отключ)"
)

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from services.data_layer.database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/daily-digest", tags=["daily-digest"])
LOCAL_CITY_UTC_OFFSET = timedelta(hours=5)

_digest_notifications: list[dict[str, Any]] = []


async def _paraphrase_incidents_with_openrouter(incidents_raw: list[str]) -> list[str]:
    if not incidents_raw:
        return []
    
    api_key = (
        os.getenv("openrouter_api_key")
        or os.getenv("OPENROUTER_API_KEY")
        or os.getenv("GEMMA_CLOUD_API_KEY")
        or os.getenv("OPENAI_API_KEY")
    )
    api_base = os.getenv("OPENAI_BASE_URL", "https://openrouter.ai/api/v1").strip().rstrip("/")
    model = os.getenv("OPENROUTER_MODEL", "google/gemini-2.5-flash").strip()
    
    if not api_key:
        return incidents_raw
        
    try:
        import httpx
        prompt = (
            "Ты — остроумный и позитивный городской журналист. Ниже приведен список происшествий из городских пабликов.\n"
            "Перескажи каждое происшествие с легким дружелюбным юмором, доброй иронией или позитивным настроем (одно емкое и сочное предложение на происшествие, без унылой сухости, канцелярщины и негатива):\n\n"
            + "\n".join(f"- {line}" for line in incidents_raw)
        )
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                f"{api_base}/chat/completions",
                json={
                    "model": model,
                    "messages": [
                        {"role": "system", "content": "Ты перефразируешь происшествия в городе своими словами, делая их веселыми, интересными и позитивными."},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.5,
                    "max_tokens": 600,
                },
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
            )
            if resp.status_code == 200:
                text_res = resp.json().get("choices", [{}])[0].get("message", {}).get("content", "")
                if text_res:
                    lines = [line.strip() for line in text_res.split("\n") if line.strip()]
                    formatted_lines = []
                    for line in lines:
                        cleaned = line.lstrip(" -—*•1234567890.)")
                        if cleaned:
                            formatted_lines.append(cleaned)
                    if len(formatted_lines) == len(incidents_raw):
                        return formatted_lines
                    elif len(formatted_lines) > 0:
                        result = []
                        for idx in range(len(incidents_raw)):
                            if idx < len(formatted_lines):
                                result.append(formatted_lines[idx])
                            else:
                                result.append(incidents_raw[idx])
                        return result
    except Exception as e:
        logger.debug("Incidents paraphrase failed: %s", e)
    
    return incidents_raw


def _parse_datetime(val) -> datetime | None:
    if not val:
        return None
    if isinstance(val, datetime):
        return val
    val_str = str(val).replace("T", " ")
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(val_str, fmt)
        except ValueError:
            continue
    return None


def _is_channel_source(source: str) -> bool:
    lowered = source.lower()
    return (
        lowered.startswith("tg:")
        or lowered.startswith("telegram:")
        or lowered.startswith("vk:")
        or lowered.startswith("vk_")
    )


async def _generate_ai_summary(reports: list[dict], incidents: list[str]) -> str:  # noqa: C901
    """Generate daily digest from all complaints and channel events for today."""
    local_date = (datetime.utcnow() + LOCAL_CITY_UTC_OFFSET).strftime("%d.%m.%Y")
    if not reports and not incidents:
        return (
            f"📅 Дайджест на {local_date}: "
            "сегодня в пабликах нет новых событий и происшествий."
        )

    categories: dict[str, int] = {}
    channel_count = 0
    citizen_count = 0
    for report in reports:
        category = str(report.get("category") or "Прочее").strip()
        categories[category] = categories.get(category, 0) + 1
        if _is_channel_source(str(report.get("source") or "")):
            channel_count += 1
        else:
            citizen_count += 1

    venues: dict[str, int] = {}
    for report in reports:
        venue = str(report.get("address") or report.get("title") or "Город").strip()
        venues[venue] = venues.get(venue, 0) + 1
    top_venues = sorted(venues.items(), key=lambda item: item[1], reverse=True)[:4]
    total = len(reports)
    sample_lines = [
        f"• {(r.get('title') or r.get('description') or 'Сигнал')[:72]}"
        for r in reports[:10]
    ]

    summary_parts = [
        f"📅 События из пабликов на {local_date}",
        "",
        f"С точным адресом в городе: {total}.",
        "",
    ]
    if top_venues:
        summary_parts.extend([
            "📍 Площадки:",
            *(f"  — {name} ({count})" for name, count in top_venues),
            "",
        ])
    if sample_lines:
        summary_parts.extend([
            "🎭 Мероприятия и события:",
            *sample_lines,
            "",
        ])
    if incidents:
        summary_parts.extend([
            "🚨 Сигналы дня (коротко):",
            *incidents,
            "",
        ])

    try:
        zai_key = os.getenv("ZAI_API_KEY", "").strip()
        if zai_key and total > 0:
            import httpx

            sample = "\n".join(
                f"- [{r.get('category', '')}] {r.get('title', '')[:60]}"
                for r in reports[:15]
            )
            prompt = (
                f"Ниже события города за сегодня из Telegram/VK:\n\n"
                f"{sample}\n\n"
                f"Сделай супер-интересный, короткий дайджест на русском (до 500 символов): напиши с юмором, позитивно и задорно, что интересного произошло, подбодри жителей! Используй эмодзи."
            )
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    f"{os.getenv('ZAI_BASE_URL', 'https://open.bigmodel.cn/api/paas/v4')}/chat/completions",
                    json={
                        "model": os.getenv("ZAI_TEXT_MODEL", "glm-5-turbo"),
                        "messages": [
                            {
                                "role": "system",
                                "content": "Ты — веселый, позитивный городской AI-аналитик и душа компании.",
                            },
                            {"role": "user", "content": prompt},
                        ],
                        "temperature": 0.7,
                        "max_tokens": 400,
                    },
                    headers={
                        "Authorization": f"Bearer {zai_key}",
                        "Content-Type": "application/json",
                    },
                )
                if resp.status_code == 200:
                    ai_text = (
                        resp.json()
                        .get("choices", [{}])[0]
                        .get("message", {})
                        .get("content", "")
                    )
                    if ai_text:
                        summary_parts.append("")
                        summary_parts.append(ai_text)
    except Exception as e:
        logger.debug("AI enrichment failed: %s", e)

    summary_parts.append("")
    summary_parts.append("📡 Пульс города")

    return "\n".join(summary_parts)


@router.get("")
@router.get("/")
async def get_latest_digest(city: str = Query("nizhnevartovsk"), db: Session = Depends(get_db)):  # noqa: C901
    """Get the latest daily digest."""
    try:
        local_now = datetime.utcnow() + LOCAL_CITY_UTC_OFFSET
        local_start = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_utc = local_start - LOCAL_CITY_UTC_OFFSET
        end_utc = start_utc + timedelta(days=1)

        # Try to load cached digest from database
        from services.data_layer.models import DailyDigest
        cached = db.query(DailyDigest).filter(DailyDigest.date == local_start, DailyDigest.city == city).first()

        # Query reports with precise coordinates and address for preview/list
        result = db.execute(
            text(
                "SELECT id, title, description, category, status, address, lat, lng, "
                "created_at, source "
                "FROM reports WHERE created_at >= :start_utc AND created_at < :end_utc "
                "AND (source LIKE 'tg:%' OR source LIKE 'telegram:%' OR source LIKE 'vk:%') "
                "AND lat IS NOT NULL AND lng IS NOT NULL "
                "AND address IS NOT NULL AND TRIM(address) <> '' "
                "AND LOWER(address) NOT LIKE 'gps %' "
                "AND (:city = 'novosibirsk' AND city = 'novosibirsk' OR :city <> 'novosibirsk' AND (city = 'nizhnevartovsk' OR city IS NULL OR city = '')) "
                "ORDER BY created_at DESC"
            ),
            {"start_utc": start_utc, "end_utc": end_utc, "city": city},
        ).fetchall()

        reports = []
        for r in result:
            dt = _parse_datetime(r[8])
            reports.append({
                "id": r[0],
                "title": r[1],
                "description": r[2],
                "category": r[3],
                "status": r[4],
                "address": r[5],
                "lat": r[6],
                "lng": r[7],
                "created_at": dt.isoformat() if dt else None,
                "source": r[9],
            })

        if cached:
            return {
                "success": True,
                "date": cached.date.isoformat() if cached.date else local_start.isoformat(),
                "total_reports": cached.total_reports,
                "ai_summary": cached.ai_summary,
                "summary": cached.ai_summary,
                "reports_preview": reports[:15],
            }

        # 2. Fetch short incident messages from public channels without details (filter to only addressless)
        incidents_result = db.execute(
            text(
                "SELECT title, description, created_at, source "
                "FROM reports WHERE created_at >= :start_utc AND created_at < :end_utc "
                "AND (source LIKE 'tg:%' OR source LIKE 'telegram:%' OR source LIKE 'vk:%') "
                "AND (lat IS NULL OR lng IS NULL OR address IS NULL OR TRIM(address) = '' "
                "OR (:city = 'novosibirsk' AND city = 'novosibirsk' OR :city <> 'novosibirsk' AND (city = 'nizhnevartovsk' OR city IS NULL OR city = ''))) "
                "ORDER BY created_at DESC"
            ),
            {"start_utc": start_utc, "end_utc": end_utc, "city": city},
        ).fetchall()

        incidents_raw = []
        incidents_meta = []
        seen_incidents = set()
        for row in incidents_result:
            title = str(row[0] or "").strip()
            desc = str(row[1] or "").strip()
            created_at = _parse_datetime(row[2])

            blob = f"{title} {desc}"
            if _EMERGENCY_KEYWORDS.search(blob):
                text_preview = title or desc
                text_preview = text_preview.replace("\n", " ").strip()
                if len(text_preview) > 120:
                    text_preview = text_preview[:117] + "..."

                key = text_preview.lower()[:40]
                if key in seen_incidents:
                    continue
                seen_incidents.add(key)

                local_time_str = ""
                if created_at:
                    local_time = created_at + LOCAL_CITY_UTC_OFFSET
                    local_time_str = local_time.strftime("[%H:%M] ")

                incidents_raw.append(text_preview)
                incidents_meta.append(local_time_str)
                if len(incidents_raw) >= 10:
                    break

        paraphrased = await _paraphrase_incidents_with_openrouter(incidents_raw)
        incidents = []
        for i, text_para in enumerate(paraphrased):
            time_str = incidents_meta[i] if i < len(incidents_meta) else ""
            incidents.append(f"  — {time_str}{text_para}")

        ai_summary = await _generate_ai_summary(reports, incidents)

        # Save generated digest to cache
        try:
            record = DailyDigest(
                date=local_start,
                city=city,
                total_reports=len(reports),
                ai_summary=ai_summary,
                top_categories="[]",
                top_streets="[]",
                mood="нейтральное"
            )
            db.add(record)
            db.commit()
            logger.info("Successfully cached daily digest in DB for %s", local_start)
        except Exception as cache_err:
            logger.warning("Failed to cache daily digest: %s", cache_err)
            db.rollback()

        return {
            "success": True,
            "date": local_start.isoformat(),
            "total_reports": len(reports),
            "ai_summary": ai_summary,
            "summary": ai_summary,
            "reports_preview": reports[:15],
        }
    except Exception as exc:
        logger.exception("daily digest failed: %s", exc)
        local_date = (datetime.utcnow() + LOCAL_CITY_UTC_OFFSET).strftime("%d.%m.%Y")
        fallback = (
            f"📅 Дайджест на {local_date}: "
            "сводка временно недоступна, попробуйте обновить позже."
        )
        return {
            "success": True,
            "date": datetime.utcnow().isoformat(),
            "total_reports": 0,
            "ai_summary": fallback,
            "summary": fallback,
            "reports_preview": [],
            "degraded": True,
        }


@router.get("/history")
async def get_digest_history(days: int = 7, db: Session = Depends(get_db)):
    """Get digest history for last N days."""
    days = min(max(days, 1), 30)
    since = datetime.now(UTC) - timedelta(days=days)

    result = db.execute(
        text(
            "SELECT DATE(created_at) as day, COUNT(*) as total, "
            "SUM(CASE WHEN status='resolved' THEN 1 ELSE 0 END) as resolved "
            "FROM reports WHERE created_at >= :since "
            "GROUP BY DATE(created_at) ORDER BY day DESC"
        ),
        {"since": since},
    ).fetchall()

    return {
        "days": days,
        "history": [
            {"date": str(r[0]), "total": r[1], "resolved": r[2] or 0} for r in result
        ],
    }


@router.post("/generate")
async def trigger_digest_generation(db: Session = Depends(get_db)):
    """Manually trigger digest generation."""
    result = await get_latest_digest(db)
    _digest_notifications.append(
        {
            "generated_at": datetime.now(UTC).isoformat(),
            "summary": result.get("ai_summary", ""),
            "total_reports": result.get("total_reports", 0),
        }
    )
    return result


def get_digest_notifications() -> list[dict]:
    """Get pending digest notifications."""
    return _digest_notifications.copy()


def clear_digest_notifications():
    """Clear pending notifications."""
    _digest_notifications.clear()
