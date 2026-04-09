import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

print('Waiting 30s...')
time.sleep(30)

for cmd in [
    'docker ps --format "table {{.Names}}\t{{.Status}}"',
    'docker logs soobshio_backend 2>&1 | tail -5',
    'curl -s http://127.0.0.1/health 2>&1',
    'curl -s http://127.0.0.1/api/gamification/achievements 2>&1 | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d[\"achievements\"]))" 2>&1',
    'curl -s -X POST http://127.0.0.1/api/gamification/memes/generate -H "Content-Type: application/json" -d "{\"telegram_id\":1,\"category\":\"random\"}" 2>&1 | head -3',
    'curl -s http://127.0.0.1/api/gamification/leaderboard?limit=3 2>&1 | head -3',
]:
    print(f'\n$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=20)
    time.sleep(5)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(out[:300])
    print('-'*40)
ssh.close()
