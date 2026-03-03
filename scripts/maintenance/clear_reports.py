#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Полная очистка жалоб в базе (таблица reports).
Запуск из корня проекта:
  py scripts/maintenance/clear_reports.py
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from backend.database import SessionLocal  # type: ignore
from backend.models import Report  # type: ignore


def main() -> int:
  db = SessionLocal()
  try:
    deleted = db.query(Report).delete(synchronize_session=False)
    db.commit()
    print(f"Deleted {deleted} reports from database.")
    return 0
  except Exception as e:
    print(f"Error clearing reports: {e}")
    db.rollback()
    return 1
  finally:
    db.close()


if __name__ == "__main__":
  raise SystemExit(main())

