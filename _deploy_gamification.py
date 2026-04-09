import paramiko, sys, time, os
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv
load_dotenv(r'c:\Soobshio_project\.env')
PASS = os.getenv('SSH_PASSWORD','')
print('Connecting...')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
print('Connected!\n')

# Upload backend files
print('Uploading backend...')
sftp = ssh.open_sftp()
files = [
    (r'c:\Soobshio_project\services\Backend\app.py', '/root/citypulse_api/services/Backend/app.py'),
    (r'c:\Soobshio_project\services\Backend\routers\gamification.py', '/root/citypulse_api/services/Backend/routers/gamification.py'),
]
for local, remote in files:
    sftp.put(local, remote)
    print(f'  OK: {remote.split("/")[-1]}')

# Upload Flutter source
flutter_files = [
    (r'c:\Soobshio_project\services\Frontend\lib\core\app_router.dart', '/root/citypulse_api/services/Frontend/lib/core/app_router.dart'),
    (r'c:\Soobshio_project\services\Frontend\lib\screens\gamification_screen.dart', '/root/citypulse_api/services/Frontend/lib/screens/gamification_screen.dart'),
    (r'c:\Soobshio_project\services\Frontend\lib\screens\meme_screen.dart', '/root/citypulse_api/services/Frontend/lib/screens/meme_screen.dart'),
    (r'c:\Soobshio_project\services\Frontend\pubspec.yaml', '/root/citypulse_api/services/Frontend/pubspec.yaml'),
    (r'c:\Soobshio_project\services\Frontend\pubspec.lock', '/root/citypulse_api/services/Frontend/pubspec.lock'),
]
for local, remote in flutter_files:
    try:
        sftp.put(local, remote)
        print(f'  OK: {remote.split("/")[-1]}')
    except Exception as e:
        print(f'  ERR: {remote.split("/")[-1]} - {e}')
sftp.close()

# Build Flutter web
print('\nBuilding Flutter web...')
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api/services/Frontend && flutter pub get 2>&1', timeout=60)
time.sleep(15)
out = stdout.read().decode('utf-8', errors='replace').strip()
if 'error' in out.lower(): print(f'pub get: {out[:200]}')
else: print('  pub get OK')

stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api/services/Frontend && flutter build web --release 2>&1 | tail -3', timeout=300)
time.sleep(180)
out = stdout.read().decode('utf-8', errors='replace').strip()
print(f'  build: {out[:200]}')

# Restart backend
print('\nRestarting backend...')
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose up -d --build backend 2>&1 | tail -10', timeout=300)
time.sleep(60)
out = stdout.read().decode('utf-8', errors='replace').strip()
if out: print(out[:300])

# Restart nginx
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose restart nginx 2>&1', timeout=30)
time.sleep(8)

# Status
print('\n=== STATUS ===')
for cmd in [
    'docker ps --format "table {{.Names}}\t{{.Status}}"',
    'curl -s http://127.0.0.1/health',
    'curl -s http://127.0.0.1/api/gamification/achievements 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\'Achievements: {len(d.get(chr(97)+chr(99)+chr(104)+chr(105)+chr(101)+chr(118)+chr(101)+chr(109)+chr(101)+chr(110)+chr(116)+chr(115),[]))}\')" 2>&1',
    'curl -s -X POST http://127.0.0.1/api/gamification/memes/generate -H "Content-Type: application/json" -d \'{"telegram_id":1,"category":"random"}\' 2>&1 | head -5',
    'curl -s http://127.0.0.1/api/gamification/leaderboard?limit=5 2>&1 | head -5',
]:
    print(f'\n$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=20)
    time.sleep(5)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(f'  {out[:300]}')
    print('-'*40)

ssh.close()
print('\nGAMIFICATION DEPLOYED ✅')
