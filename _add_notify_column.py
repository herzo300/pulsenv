"""Add notify_new column to users table"""
import sqlite3
conn = sqlite3.connect("soobshio.db")
try:
    conn.execute("ALTER TABLE users ADD COLUMN notify_new INTEGER DEFAULT 0")
    conn.commit()
    print("✅ Column notify_new added")
except Exception as e:
    print(f"Column may already exist: {e}")
conn.close()
