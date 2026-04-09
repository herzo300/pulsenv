import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
PASS = os.getenv('SSH_PASSWORD','')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
print('Uploading fixed app.py...')
sftp = ssh.open_sftp()
sftp.put(r'c:\Soobshio_project\services\Backend\app.py', '/root/citypulse_api/services/Backend/app.py')
sftp.close()

# Restart backend to create tables
print('Restarting backend...')
stdin, stdout, stderr = ssh.exec_command('cd /root/citypulse_api && docker compose restart backend 2>&1', timeout=60)
time.sleep(20)

print('Waiting for tables to be created...')
time.sleep(10)

# Test
for cmd in [
    'docker logs soobshio_backend 2>&1 | grep -i "gamification\|error\|table" | tail -10',
    'curl -s http://127.0.0.1/health 2>&1',
    'curl -s http://127.0.0.1/api/gamification/achievements 2>&1 | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"Achievements: {len(d.get(chr(97)+chr(99)+chr(104)+chr(105)+chr(101)+chr(118)+chr(101)+chr(109)+chr(101)+chr(110)+chr(116)+chr(115),[]))}\")" 2>&1',
    'curl -s "http://127.0.0.1/api/gamification/memes/generate?telegram_id=1&category=random" -X POST 2>&1 | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"Meme type: {d.get(chr(109)+chr(101)+chr(109)+chr(101)+chr(95)+chr(116)+chr(121)+chr(112)+chr(101),chr(63))}, XP: {d.get(chr(120)+chr(112)+chr(95)+chr(101)+chr(97)+chr(114)+chr(110)+chr(101)+chr(100),0)}\")" 2>&1',
    'curl -s "http://127.0.0.1/api/gamification/leaderboard?limit=3" 2>&1 | python3 -c "import sys,json;d=json.load(sys.stdin);lb=d.get(chr(108)+chr(101)+chr(97)+chr(100)+chr(101)+chr(114)+chr(98)+chr(111)+chr(97)+chr(114)+chr(100),[]);print(f\"Leaderboard: {len(lb)} entries\")" 2>&1',
    'curl -s "http://127.0.0.1/api/gamification/profile/1" 2>&1 | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"Profile: {d.get(chr(108)+chr(101)+chr(118)+chr(101)+chr(108),chr(63))}, XP: {d.get(chr(120)+chr(112),0)}\")" 2>&1',
]:
    print(f'\n$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
    time.sleep(5)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    print(out[:300] if out else '(empty)')
    print('-'*40)
ssh.close()
print('\nDONE ✅')
