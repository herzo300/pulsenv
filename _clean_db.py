"""Clean DB: remove junk/test, show stats"""
import sqlite3
conn = sqlite3.connect("soobshio.db")
c = conn.cursor()

# Delete junk
c.execute("DELETE FROM reports WHERE id = 13")  # "Жалоба" - пустая
c.execute("DELETE FROM reports WHERE source = 'test_complaint'")
deleted = conn.total_changes
print(f"Deleted: {deleted}")

# Show remaining with coords
c.execute("SELECT id, title, lat, lng, category, address FROM reports WHERE lat IS NOT NULL AND lng IS NOT NULL ORDER BY id")
rows = c.fetchall()
print(f"\nWith coords: {len(rows)}")
for r in rows:
    print(f"  #{r[0]} [{r[4]}] lat={r[2]:.4f} lng={r[3]:.4f} addr={r[5] or '-'} title={r[1][:50]}")

# Total remaining
c.execute("SELECT COUNT(*) FROM reports")
print(f"\nTotal remaining: {c.fetchone()[0]}")

conn.commit()
conn.close()
