import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

for cmd in [
    'curl -s http://127.0.0.1/api/gamification/achievements 2>&1',
    'curl -s -X POST "http://127.0.0.1/api/gamification/memes/generate" -H "Content-Type: application/json" -d "{\"telegram_id\":1,\"category\":\"random\"}" 2>&1',
    'curl -s "http://127.0.0.1/api/gamification/leaderboard?limit=3" 2>&1',
    'curl -s "http://127.0.0.1/api/gamification/profile/1" 2>&1',
]:
    print(f'\n$ {cmd[:75]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(4)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    print(out[:400] if out else '(empty)')
    print('-'*50)
ssh.close()
