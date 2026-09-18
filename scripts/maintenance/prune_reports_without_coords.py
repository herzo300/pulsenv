#!/usr/bin/env python3
"""Remove reports that have no geocoordinates (lat/lng)."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")


def _missing_coords_clause():
    from services.data_layer.models import Report

    return (Report.lat.is_(None)) | (Report.lng.is_(None))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Delete reports without lat/lng from the database."
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually delete rows (default is dry-run).",
    )
    args = parser.parse_args()

    from sqlalchemy import func

    from services.data_layer.database import SessionLocal
    from services.data_layer.models import Comment, Like, Report, UserReaction

    db = SessionLocal()
    try:
        missing = _missing_coords_clause()
        report_ids = [
            row[0]
            for row in db.query(Report.id).filter(missing).all()
        ]
        total_missing = len(report_ids)
        total_all = db.query(func.count(Report.id)).scalar() or 0
        with_coords = total_all - total_missing

        print(f"reports_total={total_all}")
        print(f"reports_without_coords={total_missing}")
        print(f"reports_with_coords={with_coords}")

        if not report_ids:
            print("Nothing to delete.")
            return 0

        if not args.apply:
            print("Dry-run only. Re-run with --apply to delete.")
            return 0

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
        deleted = (
            db.query(Report).filter(missing).delete(synchronize_session=False)
        )
        db.commit()
        print(
            f"deleted reports={deleted}, likes={likes}, "
            f"comments={comments}, reactions={reactions}"
        )
        remaining = db.query(func.count(Report.id)).scalar() or 0
        print(f"reports_remaining={remaining}")
        return 0
    except Exception as exc:
        db.rollback()
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
