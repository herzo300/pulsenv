import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

for cmd in [
    'docker logs soobshio_backend 2>&1 | grep -i "error\|traceback\|import" | tail -20',
    'cat /root/citypulse_api/services/Backend/__init__.py 2>&1',
    'cat /root/citypulse_api/services/__init__.py 2>&1',
]:
    print(f'$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(2)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(out[:300])
    print('='*40)

# Fix: rebuild backend properly
print('\nRebuilding backend...')
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose down && docker compose up -d --build backend 2>&1 | tail -20', timeout=300)
time.sleep(120)
out = stdout.read().decode('utf-8', errors='replace').strip()
print(out[:500])

time.sleep(15)

# Check
for cmd in [
    'docker ps --format "table {{.Names}}\t{{.Status}}" | grep backend',
    'curl -s http://127.0.0.1/health 2>&1',
]:
    print(f'\n$ {cmd[:60]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(4)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(out[:200])

ssh.close()
