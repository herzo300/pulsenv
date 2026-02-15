"""Удаление дублей из базы данных soobshio.db"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backend.database import SessionLocal
from backend.models import Report
from sqlalchemy import func

db = SessionLocal()

# Находим дубли по (title, description, category, address)
print("🔍 Поиск дублей...")

dupes = (
    db.query(
        Report.title, Report.description, Report.category, Report.address,
        func.count(Report.id).label("cnt"),
        func.min(Report.id).label("keep_id"),
    )
    .group_by(Report.title, Report.description, Report.category, Report.address)
    .having(func.count(Report.id) > 1)
    .all()
)

total_deleted = 0
for d in dupes:
    # Удаляем все кроме самого старого (min id)
    to_delete = (
        db.query(Report)
        .filter(
            Report.title == d.title,
            Report.description == d.description,
            Report.category == d.category,
            Report.address == d.address,
            Report.id != d.keep_id,
        )
        .all()
    )
    for r in to_delete:
        db.delete(r)
        total_deleted += 1

# Также дубли по telegram_message_id (если не None)
msg_dupes = (
    db.query(
        Report.telegram_message_id,
        func.count(Report.id).label("cnt"),
        func.min(Report.id).label("keep_id"),
    )
    .filter(Report.telegram_message_id.isnot(None), Report.telegram_message_id != "")
    .group_by(Report.telegram_message_id)
    .having(func.count(Report.id) > 1)
    .all()
)

for d in msg_dupes:
    to_delete = (
        db.query(Report)
        .filter(
            Report.telegram_message_id == d.telegram_message_id,
            Report.id != d.keep_id,
        )
        .all()
    )
    for r in to_delete:
        db.delete(r)
        total_deleted += 1

db.commit()

remaining = db.query(Report).count()
print(f"✅ Удалено дублей: {total_deleted}")
print(f"📊 Осталось жалоб: {remaining}")
db.close()
