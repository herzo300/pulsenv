import os
import sys
import json
import paramiko
from dotenv import load_dotenv

PROJECT_ROOT = r"C:\Soobshio_project"
sys.stdout.reconfigure(encoding='utf-8')
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = "45.153.68.59"
USER = "root"
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASSWORD, timeout=15)

script = """
import json
import psycopg2

conn = psycopg2.connect(
    dbname='soobshio',
    user='soobshio',
    password='C4gvI6tMoX_EnYwKXkP_RSKCKjgf1DuE',
    host='postgres',
    port=5432
)
cur = conn.cursor()
cur.execute("SELECT id, title, description, address, lat, lng, created_at, category, status, source, telegram_channel FROM reports ORDER BY id ASC;")
rows = cur.fetchall()

reports = []
for r in rows:
    reports.append({
        'id': r[0],
        'title': r[1],
        'description': r[2],
        'address': r[3],
        'lat': float(r[4]) if r[4] is not None else None,
        'lng': float(r[5]) if r[5] is not None else None,
        'created_at': str(r[6]),
        'category': r[7],
        'status': r[8],
        'source': r[9],
        'channel': r[10]
    })

print("JSON_START")
print(json.dumps(reports, ensure_ascii=False))
print("JSON_END")
"""

stdin, stdout, stderr = ssh.exec_command("docker exec -i soobshio_backend python -")
stdin.write(script)
stdin.channel.shutdown_write()

output = stdout.read().decode('utf-8')
err = stderr.read().decode('utf-8')

if "JSON_START" in output:
    json_str = output.split("JSON_START")[1].split("JSON_END")[0].strip()
    reports = json.loads(json_str)
    print(f"Total reports in database: {len(reports)}")
    with open("scratch/all_reports_db.json", "w", encoding="utf-8") as f:
        json.dump(reports, f, ensure_ascii=False, indent=2)
    
    # Check addresses
    addr_counts = {}
    for r in reports:
        addr = r.get('address', '') or 'EMPTY'
        addr_counts[addr] = addr_counts.get(addr, 0) + 1
    
    print("\n--- TOP ADDRESSES IN DB ---")
    for addr, cnt in sorted(addr_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  [{cnt}x] {addr}")
        
    print("\n--- DETAILED REPORTS WITH OMSKAYA 14V OR GENERIC ---")
    for r in reports:
        addr = r.get('address', '') or ''
        if 'омск' in addr.lower() or 'вартовск' in addr.lower() or not addr or 'ленин' in addr.lower():
            print(f"ID {r['id']}: [{addr}] ({r['lat']}, {r['lng']}) | Source: {r.get('source')}")
            print(f"  Title: {r['title']}")
            print(f"  Desc:  {r['description'][:160]}...")
            print("-" * 60)
else:
    print("Error:")
    print(output)
    print(err)

ssh.close()
