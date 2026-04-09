import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
PASS = os.getenv('SSH_PASSWORD','')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
print('Connected\n')

def run(cmd, timeout=30):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    time.sleep(2)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    return out, err

# FIX 1: Fix Flutter double /api/ prefix in map_screen.dart
print('=== FIX 1: Flutter double /api/ prefix ===')
for cmd in [
    "sed -i 's|/api/uk/by_coords|/uk/by_coords|g' /root/citypulse_api/services/Frontend/lib/screens/map_screen.dart",
    "sed -i 's|/api/uk/ratings|/uk/ratings|g' /root/citypulse_api/services/Frontend/lib/screens/map_screen.dart",
    "sed -i 's|/api/daily-digest|/daily-digest|g' /root/citypulse_api/services/Frontend/lib/screens/map/widgets/daily_digest_ticker.dart",
    "grep -n 'api/uk\\|api/daily' /root/citypulse_api/services/Frontend/lib/screens/map_screen.dart /root/citypulse_api/services/Frontend/lib/screens/map/widgets/daily_digest_ticker.dart 2>&1 | head -10",
]:
    out, err = run(cmd, 10)
    if out: print(out[:200])

# FIX 2: Fix UK coords parameter name (lng -> lon or vice versa)
print('\n=== FIX 2: UK coords param ===')
out, _ = run("grep -n 'api/uk/by_coords' /root/citypulse_api/services/Frontend/lib/screens/map_screen.dart 2>&1 | head -5", 10)
print(out[:200])

# FIX 3: Check AI sanitize endpoint
print('\n=== FIX 3: AI sanitize ===')
out, _ = run('curl -s -X POST http://127.0.0.1/api/ai/sanitize_report -H "Content-Type: application/json" -d \'{"text":"яма на ул Мира 15","image":""}\' 2>&1', 15)
print(out[:300])

# FIX 4: Check monitoring
print('\n=== FIX 4: Monitoring status ===')
out, _ = run('docker logs soobshio_monitoring 2>&1 | tail -20', 10)
print(out[:500])

# FIX 5: Check map feed min limit
print('\n=== FIX 5: Map feed ===')
out, _ = run('curl -s "http://127.0.0.1/api/map/feed?limit=50" 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\'Reports: {len(d)}\')" 2>&1', 15)
print(out[:200])

# FIX 6: Rebuild Flutter web with fixes
print('\n=== FIX 6: Rebuild Flutter web ===')
# Upload fixed files via SFTP
sftp = ssh.open_sftp()
files = [
    (r'c:\Soobshio_project\services\Frontend\lib\screens\map_screen.dart', '/root/citypulse_api/services/Frontend/lib/screens/map_screen.dart'),
    (r'c:\Soobshio_project\services\Frontend\lib\screens\map\widgets\daily_digest_ticker.dart', '/root/citypulse_api/services/Frontend/lib/screens/map/widgets/daily_digest_ticker.dart'),
]
for local, remote in files:
    try:
        sftp.put(local, remote)
        print(f'  OK: {remote.split("/")[-1]}')
    except Exception as e:
        print(f'  ERR: {e}')
sftp.close()

# Rebuild web
out, err = run('cd /root/citypulse_api/services/Frontend && flutter build web --release 2>&1 | tail -5', 180)
if out: print(out[:300])
if err: print('ERR:', err[:200])

# Restart nginx to pick up new web files
run('cd /root/citypulse_api && docker compose restart nginx 2>&1', 15)

# Final check
print('\n=== FINAL CHECK ===')
for cmd in [
    'curl -s "http://127.0.0.1/api/uk/ratings" 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"UKs: {len(d)}\")" 2>&1',
    'curl -s "http://127.0.0.1/api/uk/by_coords?lat=61.10&lon=76.58" 2>&1 | head -3',
    'curl -s "http://127.0.0.1/api/daily-digest" 2>&1 | head -3',
    'curl -s "http://127.0.0.1/api/map/feed?limit=50" 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\'Markers: {len(d)}\')" 2>&1',
    'docker ps --format "table {{.Names}}\t{{.Status}}"',
]:
    out, _ = run(cmd, 15)
    print(f'$ {cmd[:60]}')
    if out: print(f'  {out[:200]}')
    print()

ssh.close()
print('ALL FIXES APPLIED ✅')
