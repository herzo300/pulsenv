"""Add supporters, supporters_notified, uk_name, uk_email columns to reports"""
import sqlite3
conn = sqlite3.connect("soobshio.db")
c = conn.cursor()
for col, typ, default in [
    ("supporters", "INTEGER", "0"),
    ("supporters_notified", "INTEGER", "0"),
    ("uk_name", "VARCHAR(300)", "NULL"),
    ("uk_email", "VARCHAR(200)", "NULL"),
]:
    try:
        c.execute(f"ALTER TABLE reports ADD COLUMN {col} {typ} DEFAULT {default}")
        print(f"Added {col}")
    except Exception as e:
        print(f"{col}: {e}")
conn.commit()
conn.close()
print("Done")
