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

# Upload Flutter web build
print('Uploading Flutter web build...')
import glob
web_dir = r'c:\Soobshio_project\services\Frontend\build\web'
sftp = ssh.open_sftp()
count = 0
for root, dirs, files in os.walk(web_dir):
    for fname in files:
        local = os.path.join(root, fname)
        rel = os.path.relpath(local, web_dir).replace('\\', '/')
        remote = f'/root/citypulse_api/services/Frontend/build/web/{rel}'
        # Create remote dirs
        remote_dir = os.path.dirname(remote)
        try:
            sftp.stat(remote_dir)
        except:
            parts = remote_dir.replace('/root/citypulse_api', '').strip('/').split('/')
            path = '/root/citypulse_api'
            for p in parts:
                if p:
                    path += f'/{p}'
                    try:
                        sftp.mkdir(path)
                    except:
                        pass
        try:
            sftp.put(local, remote)
            count += 1
        except Exception as e:
            print(f'  ERR: {rel} - {e}')
sftp.close()
print(f'Uploaded {count} files')

# Also upload Flutter source files for monitoring/camera_probe containers
print('\nUploading Flutter source to server...')
sftp = ssh.open_sftp()
src_files = [
    (r'c:\Soobshio_project\services\Frontend\lib\screens\map_screen.dart', '/root/citypulse_api/services/Frontend/lib/screens/map_screen.dart'),
    (r'c:\Soobshio_project\services\Frontend\lib\screens\map\widgets\daily_digest_ticker.dart', '/root/citypulse_api/services/Frontend/lib/screens/map/widgets/daily_digest_ticker.dart'),
]
for local, remote in src_files:
    try:
        sftp.put(local, remote)
        print(f'  OK: {remote.split("/")[-1]}')
    except Exception as e:
        print(f'  ERR: {e}')
sftp.close()

# Restart nginx
print('\nRestarting nginx...')
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose restart nginx 2>&1', timeout=30)
time.sleep(5)
print(stdout.read().decode('utf-8', errors='replace').strip())

# Test
print('\n=== TESTS ===')
for cmd in [
    'curl -s http://127.0.0.1/api/uk/ratings 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"UK ratings: {len(d)}\")" 2>&1',
    'curl -s "http://127.0.0.1/api/uk/by_coords?lat=61.10&lon=76.58" 2>&1 | head -3',
    'curl -s http://127.0.0.1/api/daily-digest 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Digest OK: {\"ai_summary\" in d}\")" 2>&1',
    'curl -s "http://127.0.0.1/api/map/feed?limit=50" 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Map markers: {len(d)}\")" 2>&1',
    'curl -s -X POST http://127.0.0.1/api/ai/sanitize_report -H "Content-Type: application/json" -d \'{"text":"яма на ул Мира 15","image":""}\' 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"AI: {d.get(\'category\',\'?\')}\")" 2>&1',
    'docker ps --format "table {{.Names}}\t{{.Status}}"',
]:
    print(f'\n$ {cmd[:65]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=20)
    time.sleep(5)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(f'  {out[:300]}')
    print('-'*40)

ssh.close()
print('\nALL DEPLOYED ✅')
