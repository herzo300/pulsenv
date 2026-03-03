#!/usr/bin/env python3
# Добавляет колонку digest_subscription_until в users (подписка на ежедневные сводки).
# Запуск из корня: py scripts/maintenance/migrate_digest_subscription.py

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

from sqlalchemy import text
from backend.database import engine

def main():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN digest_subscription_until DATETIME"))
            conn.commit()
            print("[OK] Колонка users.digest_subscription_until добавлена.")
        except Exception as e:
            msg = str(e).lower()
            if "duplicate column" in msg or "already exists" in msg or "duplicate column name" in msg:
                print("[OK] Колонка users.digest_subscription_until уже есть.")
            else:
                raise

if __name__ == "__main__":
    main()
