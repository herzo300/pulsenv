#!/usr/bin/env python3
"""
Database maintenance for Puls Goroda / Soobshio.

Safe cleanup to keep the map API fast:
  - remove reports without coordinates
  - remove duplicate Telegram rows
  - optionally drop very old rows
  - VACUUM ANALYZE + verify indexes

Examples:
  python scripts/maintenance/maintain_database.py
  python scripts/maintenance/maintain_database.py --apply
  python scripts/maintenance/maintain_database.py --apply --vacuum --max-age-days 180
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")


def _delete_report_children(db, report_ids: list[int]) -> dict[str, int]:
    from sqlalchemy import func

    from services.data_layer.models import Comment, Like, Report, UserReaction

    if not report_ids:
        return {"likes": 0, "comments": 0, "reactions": 0}

    likes = (
        db.query(func.count(Like.id))
        .filter(Like.report_id.in_(report_ids))
        .scalar()
        or 0
    )
    comments = (
        db.query(func.count(Comment.id))
        .filter(Comment.report_id.in_(report_ids))
        .scalar()
        or 0
    )
    reactions = (
        db.query(func.count(UserReaction.id))
        .filter(UserReaction.report_id.in_(report_ids))
        .scalar()
        or 0
    )
    db.query(Like).filter(Like.report_id.in_(report_ids)).delete(
        synchronize_session=False
    )
    db.query(Comment).filter(Comment.report_id.in_(report_ids)).delete(
        synchronize_session=False
    )
    db.query(UserReaction).filter(UserReaction.report_id.in_(report_ids)).delete(
        synchronize_session=False
    )
    db.query(Report).filter(Report.id.in_(report_ids)).delete(
        synchronize_session=False
    )
    return {
        "likes": int(likes),
        "comments": int(comments),
        "reactions": int(reactions),
    }


def _stats(db) -> dict[str, int]:
    from sqlalchemy import func

    from services.data_layer.models import Report

    total = db.query(func.count(Report.id)).scalar() or 0
    with_coords = (
        db.query(func.count(Report.id))
        .filter(Report.lat.isnot(None), Report.lng.isnot(None))
        .scalar()
        or 0
    )
    tg = (
        db.query(func.count(Report.id))
        .filter(Report.source.like("tg:%"))
        .scalar()
        or 0
    )
    return {
        "reports_total": int(total),
        "reports_with_coords": int(with_coords),
        "reports_without_coords": int(total - with_coords),
        "reports_tg": int(tg),
    }


def _prune_without_coords(db, *, apply: bool) -> dict[str, int]:
    from services.data_layer.models import Report

    ids = [
        row[0]
        for row in db.query(Report.id)
        .filter((Report.lat.is_(None)) | (Report.lng.is_(None)))
        .all()
    ]
    if not apply:
        return {"candidates": len(ids), "deleted": 0}
    child_stats = _delete_report_children(db, ids)
    return {"candidates": len(ids), "deleted": len(ids), **child_stats}


def _prune_old_reports(db, *, apply: bool, max_age_days: int) -> dict[str, int]:
    from services.data_layer.models import Report

    cutoff = datetime.utcnow() - timedelta(days=max_age_days)
    ids = [
        row[0]
        for row in db.query(Report.id)
        .filter(Report.created_at.isnot(None), Report.created_at < cutoff)
        .all()
    ]
    if not apply:
        return {"candidates": len(ids), "deleted": 0}
    child_stats = _delete_report_children(db, ids)
    return {"candidates": len(ids), "deleted": len(ids), **child_stats}


def _prune_duplicates(db, *, apply: bool) -> dict[str, int]:
    from services.data_layer.models import Report

    rows = (
        db.query(
            Report.id,
            Report.telegram_channel,
            Report.telegram_message_id,
            Report.source,
            Report.title,
            Report.created_at,
        )
        .order_by(Report.created_at.desc(), Report.id.desc())
        .all()
    )

    delete_ids: set[int] = set()

    by_tg_msg: dict[tuple[str, str], list[int]] = defaultdict(list)
    for row in rows:
        channel = (row.telegram_channel or "").strip()
        msg_id = (row.telegram_message_id or "").strip()
        if channel and msg_id:
            by_tg_msg[(channel, msg_id)].append(int(row.id))

    for ids in by_tg_msg.values():
        if len(ids) > 1:
            delete_ids.update(ids[1:])

    by_source_key: dict[str, list[int]] = defaultdict(list)
    for row in rows:
        source = (row.source or "").strip().lower()
        if source.startswith("tg:") and "#" in source:
            by_source_key[source].append(int(row.id))

    for ids in by_source_key.values():
        if len(ids) > 1:
            delete_ids.update(ids[1:])

    if not apply:
        return {"candidates": len(delete_ids), "deleted": 0}

    child_stats = _delete_report_children(db, sorted(delete_ids))
    return {"candidates": len(delete_ids), "deleted": len(delete_ids), **child_stats}


def _vacuum_reports() -> None:
    from services.data_layer.database import engine

    if str(engine.url).startswith("sqlite"):
        print("vacuum: skipped for sqlite")
        return

    raw = engine.raw_connection()
    try:
        raw.set_isolation_level(0)
        cursor = raw.cursor()
        cursor.execute("VACUUM ANALYZE reports")
        cursor.close()
        print("vacuum: VACUUM ANALYZE reports — ok")
    finally:
        raw.close()


def _ensure_indexes() -> None:
    import subprocess

    script = ROOT / "scripts" / "maintenance" / "ensure_runtime_indexes.py"
    subprocess.run([sys.executable, str(script)], cwd=str(ROOT), check=False)


def main() -> int:
    parser = argparse.ArgumentParser(description="Maintain reports database")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply changes (default is dry-run).",
    )
    parser.add_argument(
        "--vacuum",
        action="store_true",
        help="Run VACUUM ANALYZE on reports (PostgreSQL only).",
    )
    parser.add_argument(
        "--max-age-days",
        type=int,
        default=0,
        help="Also delete reports older than N days (0 = disabled).",
    )
    parser.add_argument(
        "--skip-indexes",
        action="store_true",
        help="Do not recreate/verify runtime indexes.",
    )
    args = parser.parse_args()

    from services.data_layer.database import SessionLocal

    db = SessionLocal()
    try:
        before = _stats(db)
        print("before", before)

        steps = {
            "without_coords": _prune_without_coords(db, apply=args.apply),
            "duplicates": _prune_duplicates(db, apply=args.apply),
        }
        if args.max_age_days > 0:
            steps["older_than_days"] = _prune_old_reports(
                db,
                apply=args.apply,
                max_age_days=args.max_age_days,
            )

        if args.apply:
            db.commit()
        else:
            db.rollback()
            print("dry-run: no changes committed")

        print("steps", steps)

        if args.apply:
            after = _stats(db)
            print("after", after)

        if args.vacuum and args.apply:
            db.close()
            db = None
            _vacuum_reports()

        if args.apply and not args.skip_indexes:
            _ensure_indexes()

        return 0
    except Exception as exc:
        db.rollback()
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    finally:
        if db is not None:
            db.close()


if __name__ == "__main__":
    raise SystemExit(main())
