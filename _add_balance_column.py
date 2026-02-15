"""Add balance column to users table if not exists"""
import sqlite3

conn = sqlite3.connect('soobshio.db')
c = conn.cursor()
try:
    c.execute("ALTER TABLE users ADD COLUMN balance INTEGER DEFAULT 0")
    conn.commit()
    print("Added balance column")
except sqlite3.OperationalError as e:
    if 'duplicate' in str(e).lower():
        print("Column already exists")
    else:
        print(f"Error: {e}")
conn.close()
