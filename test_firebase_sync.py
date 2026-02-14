#!/usr/bin/env python3
"""Тест: Firebase RTDB push + read"""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from services.firebase_service import push_complaint, get_recent_complaints, FIREBASE_RTDB_URL


async def main():
    print("=" * 50)
    print("ТЕСТ FIREBASE RTDB СИНХРОНИЗАЦИЯ")
    print("=" * 50)

    print(f"Firebase URL: {FIREBASE_RTDB_URL}")

    # Тест 1: Push жалобы
    print("\n--- Тест 1: Push жалобы ---")
    doc_id = await push_complaint({
        "category": "Дороги",
        "summary": "Тестовая жалоба — яма на ул. Мира",
        "text": "Большая яма на ул. Мира 10, опасно для пешеходов",
        "address": "ул. Мира, 10",
        "lat": 60.9380,
        "lng": 76.5968,
        "source": "test",
        "source_name": "test_script",
        "post_link": "",
        "provider": "test",
    })
    if doc_id:
        print(f"✅ Push OK, doc_id: {doc_id}")
    else:
        print("❌ Push failed")

    # Тест 2: Чтение жалоб
    print("\n--- Тест 2: Чтение жалоб ---")
    complaints = await get_recent_complaints(limit=5)
    print(f"📋 Жалоб в Firebase: {len(complaints)}")
    for c in complaints[:3]:
        cat = c.get("category", "?")
        summary = c.get("summary", "?")[:50]
        src = c.get("source", "?")
        print(f"   • [{cat}] {summary} (src: {src})")

    # Тест 3: Push из SQLite
    print("\n--- Тест 3: Чтение из SQLite ---")
    try:
        from backend.database import SessionLocal
        from backend.models import Report
        db = SessionLocal()
        total = db.query(Report).count()
        recent = db.query(Report).order_by(Report.created_at.desc()).limit(3).all()
        print(f"📋 Жалоб в SQLite: {total}")
        for r in recent:
            print(f"   • #{r.id} [{r.category}] {r.title[:50]} (src: {r.source})")
        db.close()
    except Exception as e:
        print(f"❌ SQLite error: {e}")

    print("\n✅ Тесты завершены")


asyncio.run(main())
