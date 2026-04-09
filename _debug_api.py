import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

# Check logs
stdin, stdout, stderr = ssh.exec_command('docker logs soobshio_backend 2>&1 | grep -i "error\|exception\|gamification" | tail -20', timeout=15)
time.sleep(3)
out = stdout.read().decode('utf-8', errors='replace').strip()
print('Backend logs:')
print(out[:1000] if out else '(no gamification errors)')

# Fix: memes/generate should accept body, not query params
# Fix: use POST with JSON body
for cmd in [
    # Profile
    'curl -sv http://127.0.0.1/api/gamification/profile/1 2>&1 | head -15',
    # Achievements - check raw response
    'curl -sv http://127.0.0.1/api/gamification/achievements 2>&1 | head -20',
    # Memes with query param (fix the endpoint)
    'curl -s -X POST "http://127.0.0.1/api/gamification/memes/generate?telegram_id=1&category=random" 2>&1',
    # Leaderboard
    'curl -sv http://127.0.0.1/api/gamification/leaderboard?limit=3 2>&1 | head -15',
]:
    print(f'\n$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(3)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    print(out[:400] if out else '(empty)')
    print('-'*40)

ssh.close()
