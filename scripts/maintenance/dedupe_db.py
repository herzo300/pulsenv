import sqlite3

def clean_duplicates():
    conn = sqlite3.connect('soobshio.db')
    c = conn.cursor()
    
    # Get all reports
    c.execute("SELECT id, title, address, created_at FROM reports ORDER BY id ASC")
    rows = c.fetchall()
    
    seen = set()
    deleted_ids = []
    
    for row in rows:
        r_id, title, address, created_at = row
        # Normalize key for deduplication
        key = (title.strip().lower(), (address or '').strip().lower())
        if key in seen:
            deleted_ids.append(r_id)
        else:
            seen.add(key)
            
    if deleted_ids:
        print(f"Deleting {len(deleted_ids)} duplicate reports: {deleted_ids}")
        c.executemany("DELETE FROM reports WHERE id = ?", [(i,) for i in deleted_ids])
        conn.commit()
    else:
        print("No duplicate reports found in SQLite DB.")
        
    conn.close()

if __name__ == '__main__':
    clean_duplicates()
