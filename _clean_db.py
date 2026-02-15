"""Полная очистка базы жалоб"""
import sqlite3
conn = sqlite3.connect('soobshio.db')
c = conn.cursor()
c.execute("SELECT COUNT(*) FROM reports")
before = c.fetchone()[0]
c.execute("DELETE FROM comments")
c.execute("DELETE FROM likes")
c.execute("DELETE FROM reports")
conn.commit()
c.execute("SELECT COUNT(*) FROM reports")
after = c.fetchone()[0]
print(f"Очищено: {before} -> {after} жалоб")
c.execute("VACUUM")
conn.commit()
conn.close()
print("База очищена и оптимизирована")
