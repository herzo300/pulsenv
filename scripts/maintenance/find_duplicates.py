#!/usr/bin/env python3
"""Find and fix duplicate signals (same address+category) in the DB, and verify address markers."""
import sqlite3
import sys

DB_PATH = "services/Backend/soobshio.db"

def main():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    # 1. Find duplicates by address+category (same address + same category => duplicate)
    print("=" * 80)
    print("=== ПОИСК ДУБЛИКАТОВ (одинаковый адрес + категория) ===")
    print("=" * 80)
    c.execute("""
        SELECT address, category, COUNT(*) as cnt, GROUP_CONCAT(id, ', ') as ids
        FROM reports
        WHERE address IS NOT NULL AND address != ''
        GROUP BY LOWER(TRIM(address)), LOWER(TRIM(category))
        HAVING cnt > 1
        ORDER BY cnt DESC
    """)
    duplicates = c.fetchall()
    for row in duplicates:
        print(f"  [{row['cnt']}x] addr='{row['address']}' | cat='{row['category']}' | IDs: {row['ids']}")

    # 2. List signals at Победы 3
    print("\n" + "=" * 80)
    print("=== СИГНАЛЫ НА ПРОСПЕКТ ПОБЕДЫ 3 ===")
    print("=" * 80)
    c.execute("""
        SELECT id, title, address, category, lat, lng
        FROM reports
        WHERE LOWER(address) LIKE '%побед%3%'
           OR LOWER(title) LIKE '%побед%3%'
    """)
    for row in c.fetchall():
        print(f"  ID={row['id']} | title={str(row['title'])[:60]} | addr={row['address']} | cat={row['category']} | ({row['lat']}, {row['lng']})")

    # 3. Check Ленина 17 vs Менделеева 6
    print("\n" + "=" * 80)
    print("=== СИГНАЛЫ НА ЛЕНИНА 17 / МЕНДЕЛЕЕВА 6 ===")
    print("=" * 80)
    c.execute("""
        SELECT id, title, address, category, lat, lng
        FROM reports
        WHERE LOWER(address) LIKE '%ленина%17%'
           OR LOWER(address) LIKE '%менделеева%6%'
           OR LOWER(title) LIKE '%ленина%17%'
           OR LOWER(title) LIKE '%менделеева%6%'
    """)
    for row in c.fetchall():
        print(f"  ID={row['id']} | title={str(row['title'])[:60]} | addr={row['address']} | cat={row['category']} | ({row['lat']}, {row['lng']})")

    # 4. Show all reports summary
    print("\n" + "=" * 80)
    print("=== ВСЕ СИГНАЛЫ (последние 50) ===")
    print("=" * 80)
    c.execute("SELECT id, title, address, category, lat, lng FROM reports ORDER BY id DESC LIMIT 50")
    for row in c.fetchall():
        print(f"  ID={row['id']} | title={str(row['title'])[:50]} | addr={str(row['address'])[:50]} | ({row['lat']}, {row['lng']})")

    conn.close()

if __name__ == "__main__":
    main()
