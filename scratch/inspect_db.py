import sqlite3

conn = sqlite3.connect('soobshio.db')
cursor = conn.cursor()
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = [r[0] for r in cursor.fetchall()]
print('Tables in soobshio.db:', tables)

for table in tables:
    try:
        cursor.execute(f"SELECT count(*) FROM {table}")
        cnt = cursor.fetchone()[0]
        print(f"Table '{table}': {cnt} rows")
    except Exception as e:
        print(f"Table '{table}' error: {e}")

# Check columns of reports / complaints table
for target in ['reports', 'complaints', 'lost_found']:
    if target in tables:
        cursor.execute(f"PRAGMA table_info({target});")
        cols = cursor.fetchall()
        print(f"\nColumns for {target}:")
        for col in cols:
            print(f"  {col[1]} ({col[2]})")
