import paramiko, sys, time, json
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
PASS = os.getenv('SSH_PASSWORD','')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
print('=== TESTING ALL API ENDPOINTS ===\n')

tests = [
    # Core
    ('GET', 'http://127.0.0.1/health', 'Health check'),
    ('GET', 'http://127.0.0.1/categories', 'Categories'),
    ('GET', 'http://127.0.0.1/api/infographic_data', 'Infographic data'),
    
    # Reports
    ('GET', 'http://127.0.0.1/api/reports?limit=3', 'Reports list'),
    ('GET', 'http://127.0.0.1/api/map/feed?limit=3', 'Map feed'),
    
    # Double /api/ prefix bugs
    ('GET', 'http://127.0.0.1/api/uk/ratings', 'UK ratings (correct path)'),
    ('GET', 'http://127.0.0.1/api/api/uk/ratings', 'UK ratings (double /api/ - BUG)'),
    ('GET', 'http://127.0.0.1/api/uk/by_coords?lat=61.1&lng=76.58', 'UK by coords (correct)'),
    ('GET', 'http://127.0.0.1/api/api/uk/by_coords?lat=61.1&lng=76.58', 'UK by coords (double /api/ - BUG)'),
    ('GET', 'http://127.0.0.1/api/daily-digest', 'Daily digest (correct)'),
    ('GET', 'http://127.0.0.1/api/api/daily-digest', 'Daily digest (double /api/ - BUG)'),
    
    # AI
    ('POST', 'http://127.0.0.1/api/ai/sanitize_report', 'AI sanitize', '{"text":"яма на дороге ул Ленина 15","image":""}'),
    
    # Complaints
    ('POST', 'http://127.0.0.1/complaints', 'Create complaint', '{"title":"test","category":"Дороги"}'),
    
    # Cameras
    ('GET', 'http://127.0.0.1/api/cameras', 'Cameras list'),
    
    # Admin
    ('GET', 'http://127.0.0.1/api/admin/metrics', 'Admin metrics'),
    
    # Missing endpoints
    ('POST', 'http://127.0.0.1/api/viptask/toggle', 'VIP task toggle (MISSING?)', '{"telegram_id":123,"action":"start"}'),
    ('GET', 'http://127.0.0.1/api/opendata_summaries', 'Opendata summaries (MISSING?)'),
]

for t in tests:
    method, url, name = t[0], t[1], t[2]
    body = t[3] if len(t) > 3 else None
    cmd = f'curl -s -o /tmp/_resp -w "%{{http_code}}" -X {method}'
    if body:
        cmd += f' -H "Content-Type: application/json" -d \'{body}\''
    cmd += f' {url} 2>&1'
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(2)
    code = stdout.read().decode('utf-8', errors='replace').strip()
    stdin2, stdout2, _ = ssh.exec_command('cat /tmp/_resp 2>&1', timeout=5)
    resp = stdout2.read().decode('utf-8', errors='replace').strip()[:200]
    status = '✅' if code.startswith('2') else ('⚠️' if code.startswith('4') else '❌')
    print(f'{status} {name}: HTTP {code}')
    if resp and code not in ('200',):
        print(f'   {resp[:150]}')
    print()

ssh.close()
print('=== TESTS COMPLETE ===')
