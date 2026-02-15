"""Analyze DB for identical/test complaints to remove"""
import sqlite3
conn = sqlite3.connect("soobshio.db")
c = conn.cursor()
c.execute("SELECT id, title, description, category, status, source, created_at, lat, lng, address FROM reports ORDER BY id")
rows = c.fetchall()
print(f"Total: {len(rows)}")
print()

# Group by similar titles
from difflib import SequenceMatcher
to_delete = []
seen = {}

for r in rows:
    rid, title, desc, cat, status, src, created, lat, lng, addr = r
    t = (title or "").strip().lower()
    d = (desc or "").strip().lower()
    
    # Test/junk detection
    is_junk = False
    junk_words = ['тест', 'test', 'проверка', 'aaa', 'bbb', 'xxx', 'yyy', 'zzz', 'asdf', 'qwer', 'hello', 'привет тест']
    if len(t) < 5 and not d:
        is_junk = True
    if any(jw in t for jw in junk_words):
        is_junk = True
    if any(jw in d for jw in junk_words):
        is_junk = True
    if t in ['', '-', '.', '..', '...', 'null', 'none', 'undefined']:
        is_junk = True
    
    # Identical title check
    if t in seen and not is_junk:
        prev = seen[t]
        # Same title from different sources at different times = likely duplicate
        ratio = SequenceMatcher(None, d, (prev[2] or "").strip().lower()).ratio()
        if ratio > 0.7:
            is_junk = True
            print(f"  DUP #{rid} ~ #{prev[0]}: [{cat}] {title[:60]}... (sim={ratio:.0%})")
    
    if is_junk:
        to_delete.append(rid)
        print(f"  JUNK #{rid}: [{cat}] src={src} title={title[:80]}")
    else:
        seen[t] = r

print(f"\nTo delete: {len(to_delete)} of {len(rows)}")
print(f"IDs: {to_delete}")

# Show categories distribution
c.execute("SELECT category, COUNT(*) FROM reports GROUP BY category ORDER BY COUNT(*) DESC")
print("\nCategories:")
for cat, cnt in c.fetchall():
    print(f"  {cat}: {cnt}")

# Show sources
c.execute("SELECT source, COUNT(*) FROM reports GROUP BY source ORDER BY COUNT(*) DESC")
print("\nSources:")
for src, cnt in c.fetchall():
    print(f"  {src}: {cnt}")

# Show complaints without coords
c.execute("SELECT COUNT(*) FROM reports WHERE lat IS NULL OR lng IS NULL")
print(f"\nWithout coords: {c.fetchone()[0]}")

conn.close()
