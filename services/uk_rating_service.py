# services/uk_rating_service.py
"""
Рейтинг управляющих компаний (УК) Нижневартовска.
Агрегирует данные из жалоб по каждой УК → формирует публичный рейтинг.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

from sqlalchemy import func, and_, case

from backend.database import SessionLocal
from backend.models import Report, UKRating

logger = logging.getLogger(__name__)


def _contacts_lookup() -> Dict[str, Dict[str, Any]]:
    try:
        from services.uk_service import get_all_uk_emails

        contacts: Dict[str, Dict[str, Any]] = {}
        for row in get_all_uk_emails():
            name = str(row.get("name") or "").strip()
            if not name:
                continue
            contacts[name.lower()] = {
                "email": row.get("email"),
                "phone": row.get("phone"),
                "houses": row.get("houses"),
            }
        return contacts
    except Exception as exc:
        logger.warning("UK contacts lookup failed: %s", exc)
        return {}


def recalculate_all_ratings() -> int:
    """
    Пересчитать рейтинг ВСЕХ УК на основе данных из таблицы reports.
    Вызывать по расписанию (раз в час или при запросе).
    Returns count of UK processed.
    """
    db = SessionLocal()
    try:
        # Group complaints by uk_name
        uk_stats = (
            db.query(
                Report.uk_name,
                func.count(Report.id).label("total"),
                func.sum(case((Report.status == "resolved", 1), else_=0)).label("resolved"),
                func.avg(
                    case(
                        (
                            and_(Report.status == "resolved", Report.updated_at.isnot(None)),
                            func.julianday(Report.updated_at) - func.julianday(Report.created_at),
                        ),
                        else_=None,
                    )
                ).label("avg_days"),
            )
            .filter(Report.uk_name.isnot(None), Report.uk_name != "")
            .group_by(Report.uk_name)
            .all()
        )

        count = 0
        for row in uk_stats:
            uk_name = row.uk_name
            total = row.total or 0
            resolved = row.resolved or 0
            avg_days = row.avg_days

            if total == 0:
                continue

            # Calculate overall score (0-100)
            resolve_ratio = resolved / total if total > 0 else 0
            response_score = _response_time_score(avg_days)

            # Check for repeat complaints (same address, same category within 30 days)
            repeat_rate = _calculate_repeat_rate(db, uk_name)

            # Get existing citizen score
            existing = db.query(UKRating).filter(UKRating.uk_name == uk_name).first()
            citizen_score = existing.citizen_score if existing else 0.0
            citizen_votes = existing.citizen_votes if existing else 0

            # Weighted formula
            overall = (
                resolve_ratio * 40 +
                response_score * 30 +
                (citizen_score / 5.0) * 20 +
                (1.0 - repeat_rate) * 10
            )
            overall = round(max(0, min(100, overall)), 1)

            if existing:
                existing.total_complaints = total
                existing.resolved_complaints = resolved
                existing.avg_response_days = round(avg_days, 1) if avg_days else None
                existing.repeat_complaint_rate = round(repeat_rate, 3)
                existing.overall_score = overall
            else:
                rating = UKRating(
                    uk_name=uk_name,
                    total_complaints=total,
                    resolved_complaints=resolved,
                    avg_response_days=round(avg_days, 1) if avg_days else None,
                    citizen_score=0.0,
                    citizen_votes=0,
                    repeat_complaint_rate=round(repeat_rate, 3),
                    overall_score=overall,
                )
                db.add(rating)
            count += 1

        db.commit()
        logger.info("⭐ UK ratings recalculated: %d companies", count)
        return count
    except Exception as e:
        logger.error("UK rating recalc error: %s", e)
        db.rollback()
        return 0
    finally:
        db.close()


def _response_time_score(avg_days: Optional[float]) -> float:
    """Convert avg response days to 0-1 score. Faster = higher."""
    if avg_days is None:
        return 0.3  # unknown = mediocre
    if avg_days <= 1:
        return 1.0
    if avg_days <= 3:
        return 0.85
    if avg_days <= 7:
        return 0.65
    if avg_days <= 14:
        return 0.4
    if avg_days <= 30:
        return 0.2
    return 0.05


def _calculate_repeat_rate(db, uk_name: str) -> float:
    """Calculate % of complaints that are repeats (same address+category within 30d)."""
    month_ago = datetime.utcnow() - timedelta(days=30)
    total = (
        db.query(func.count(Report.id))
        .filter(Report.uk_name == uk_name, Report.created_at >= month_ago)
        .scalar()
    )
    if not total or total < 3:
        return 0.0

    # Find addresses with >1 complaint of same category
    repeats = (
        db.query(func.count(Report.id))
        .filter(
            Report.uk_name == uk_name,
            Report.created_at >= month_ago,
            Report.address.isnot(None),
        )
        .group_by(Report.address, Report.category)
        .having(func.count(Report.id) > 1)
        .all()
    )
    repeat_count = sum(r[0] - 1 for r in repeats)  # extra complaints
    return min(1.0, repeat_count / total)


def get_all_ratings(limit: int = 50) -> List[Dict[str, Any]]:
    """Get all UK ratings sorted by score (best first)."""
    db = SessionLocal()
    try:
        contacts = _contacts_lookup()
        ratings = (
            db.query(UKRating)
            .order_by(UKRating.overall_score.desc())
            .limit(limit)
            .all()
        )
        if ratings:
            return [_format_rating(r, contacts=contacts) for r in ratings]

        # Fallback: expose the catalog even when no aggregate rating rows exist yet.
        try:
            from services.uk_service import get_all_uk_emails

            fallback_rows = get_all_uk_emails()[:limit]
            return [
                {
                    "uk_name": row.get("name") or "УК",
                    "overall_score": 0.0,
                    "grade": "—",
                    "total_complaints": 0,
                    "resolved_complaints": 0,
                    "resolve_percent": 0,
                    "avg_response_days": None,
                    "citizen_score": 0.0,
                    "citizen_votes": 0,
                    "repeat_complaint_rate": 0.0,
                    "updated_at": None,
                    "email": row.get("email"),
                    "phone": row.get("phone"),
                    "houses": row.get("houses"),
                }
                for row in fallback_rows
            ]
        except Exception as exc:
            logger.warning("UK fallback catalog error: %s", exc)
            return []
    finally:
        db.close()


def get_rating_by_name(uk_name: str) -> Optional[Dict[str, Any]]:
    """Get single UK rating by name."""
    db = SessionLocal()
    try:
        r = db.query(UKRating).filter(UKRating.uk_name == uk_name).first()
        return _format_rating(r, contacts=_contacts_lookup()) if r else None
    finally:
        db.close()


def submit_citizen_vote(uk_name: str, score: float) -> Optional[Dict[str, Any]]:
    """Submit citizen review (1-5 stars). Returns updated rating."""
    if score < 1 or score > 5:
        return None
    db = SessionLocal()
    try:
        r = db.query(UKRating).filter(UKRating.uk_name == uk_name).first()
        if not r:
            r = UKRating(uk_name=uk_name, citizen_score=score, citizen_votes=1)
            db.add(r)
        else:
            # Running average
            total_score = r.citizen_score * r.citizen_votes + score
            r.citizen_votes += 1
            r.citizen_score = round(total_score / r.citizen_votes, 2)
        db.commit()
        db.refresh(r)
        return _format_rating(r)
    finally:
        db.close()


def _format_rating(
    r: UKRating,
    *,
    contacts: Optional[Dict[str, Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    resolve_pct = (
        round(r.resolved_complaints / r.total_complaints * 100, 1)
        if r.total_complaints > 0
        else 0
    )
    contact_info = (contacts or {}).get((r.uk_name or "").strip().lower(), {})
    # Grade label
    if r.overall_score >= 80:
        grade = "A"
    elif r.overall_score >= 60:
        grade = "B"
    elif r.overall_score >= 40:
        grade = "C"
    elif r.overall_score >= 20:
        grade = "D"
    else:
        grade = "F"

    return {
        "uk_name": r.uk_name,
        "overall_score": r.overall_score,
        "grade": grade,
        "total_complaints": r.total_complaints,
        "resolved_complaints": r.resolved_complaints,
        "resolve_percent": resolve_pct,
        "avg_response_days": r.avg_response_days,
        "citizen_score": r.citizen_score,
        "citizen_votes": r.citizen_votes,
        "repeat_complaint_rate": r.repeat_complaint_rate,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
        "email": contact_info.get("email"),
        "phone": contact_info.get("phone"),
        "houses": contact_info.get("houses"),
    }
