"""Умная дедупликация: удаление тестовых и похожих по контексту жалоб"""
import os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from difflib import SequenceMatcher
from backend.database import SessionLocal
from backend.models import Report

db = SessionLocal()
reports = db.query(Report).order_by(Report.id).all()
print(f"📊 Всего жалоб: {len(reports)}")

to_delete = set()

# 1. Удаляем тестовые жалобы
test_patterns = [
    r'^test\b', r'^cluster test', r'^third test', r'^testing',
    r'^оплатить$', r'^тест\b',
]
for r in reports:
    title = (r.title or '').lower().strip()
    desc = (r.description or '').lower().strip()
    cat = (r.category or '').lower()
    # Тестовые
    for pat in test_patterns:
        if re.search(pat, title, re.I) or re.search(pat, desc, re.I):
            to_delete.add(r.id)
            break
    # Категория "other" (не русская) — скорее всего тест
    if cat == 'other':
        to_delete.add(r.id)
    # Категория с мусорными символами
    if cat and '?' in cat:
        to_delete.add(r.id)

print(f"🧹 Тестовых/мусорных: {len(to_delete)}")

# 2. Похожие по контексту (SequenceMatcher > 0.75)
real_reports = [r for r in reports if r.id not in to_delete]
print(f"📋 Реальных жалоб для проверки: {len(real_reports)}")

def text_of(r):
    return ((r.title or '') + ' ' + (r.description or '')).lower().strip()[:300]

similar_pairs = []
for i in range(len(real_reports)):
    if real_reports[i].id in to_delete:
        continue
    ti = text_of(real_reports[i])
    if len(ti) < 20:
        continue
    for j in range(i + 1, len(real_reports)):
        if real_reports[j].id in to_delete:
            continue
        tj = text_of(real_reports[j])
        if len(tj) < 20:
            continue
        # Быстрая проверка — если первые 50 символов совпадают на 60%+
        ratio = SequenceMatcher(None, ti[:100], tj[:100]).ratio()
        if ratio > 0.70:
            # Полная проверка
            full_ratio = SequenceMatcher(None, ti, tj).ratio()
            if full_ratio > 0.70:
                similar_pairs.append((real_reports[i], real_reports[j], full_ratio))
                # Удаляем более новый (больший id)
                to_delete.add(real_reports[j].id)

print(f"\n🔍 Найдено похожих пар: {len(similar_pairs)}")
for a, b, ratio in similar_pairs:
    print(f"  [{ratio:.0%}] #{a.id} vs #{b.id}")
    print(f"    A: {(a.title or '')[:70]}")
    print(f"    B: {(b.title or '')[:70]}")

# 3. Удаляем
print(f"\n🗑️ Удаляем {len(to_delete)} жалоб: {sorted(to_delete)}")
deleted = 0
for rid in to_delete:
    r = db.query(Report).filter(Report.id == rid).first()
    if r:
        db.delete(r)
        deleted += 1

db.commit()
remaining = db.query(Report).count()
print(f"✅ Удалено: {deleted}")
print(f"📊 Осталось: {remaining}")
db.close()
