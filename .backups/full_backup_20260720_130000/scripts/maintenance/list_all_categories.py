# scripts/maintenance/list_all_categories.py
import sqlite3

def main():
    conn = sqlite3.connect("soobshio.db")
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT DISTINCT category FROM reports WHERE category IS NOT NULL AND category != '';")
        categories = [r[0] for r in cursor.fetchall()]
        print("Unique categories in SQLite:", categories)
    except Exception as e:
        print("Error:", e)
    finally:
        conn.close()

if __name__ == "__main__":
    main()
