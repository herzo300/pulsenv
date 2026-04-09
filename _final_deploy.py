import paramiko, sys, time, os
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)
print('Uploading web build...')

web_dir = r'c:\Soobshio_project\services\Frontend\build\web'
sftp = ssh.open_sftp()
count = 0
for root, dirs, files in os.walk(web_dir):
    for fname in files:
        local = os.path.join(root, fname)
        rel = os.path.relpath(local, web_dir).replace('\\', '/')
        remote = f'/root/citypulse_api/services/Frontend/build/web/{rel}'
        remote_dir = os.path.dirname(remote)
        try:
            sftp.stat(remote_dir)
        except:
            parts = remote_dir.replace('/root/citypulse_api', '').strip('/').split('/')
            path = '/root/citypulse_api'
            for p in parts:
                if p:
                    path += f'/{p}'
                    try: sftp.mkdir(path)
                    except: pass
        try:
            sftp.put(local, remote)
            count += 1
        except: pass
sftp.close()
print(f'Uploaded {count} files')

# Restart nginx
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose restart nginx 2>&1', timeout=30)
time.sleep(5)

print('\n=== FINAL API TESTS ===')
for cmd in [
    'curl -s http://127.0.0.1/health',
    'curl -s http://127.0.0.1/categories | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\'Categories: {len(d[chr(99)+chr(97)+chr(116)+chr(101)+chr(103)+chr(111)+chr(114)+chr(105)+chr(101)+chr(115)])}\')" 2>&1',
    'curl -s "http://127.0.0.1/api/uk/by_coords?lat=61.10&lng=76.58"',
    'curl -s http://127.0.0.1/api/daily-digest | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Digest: {list(d.keys())}\")" 2>&1',
    'curl -s "http://127.0.0.1/api/map/feed?limit=50" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Map markers: {len(d)}\")" 2>&1',
    'docker ps --format "table {{.Names}}\t{{.Status}}"',
    'df -h / | tail -1',
]:
    print(f'\n$ {cmd[:65]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=20)
    time.sleep(4)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(f'  {out[:250]}')
    print('-'*40)
ssh.close()
print('\nALL DONE ✅')
