import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

# Check detailed errors
for cmd in [
    # Full leaderboard error
    'curl -sv http://127.0.0.1/api/gamification/leaderboard?limit=3 2>&1',
    # Full achievements response
    'curl -sv http://127.0.0.1/api/gamification/achievements 2>&1',
    # Check if tables exist
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "\\dt user_*" 2>&1',
    'docker exec soobshio_postgres psql -U soobshio -d soobshio -c "\\dt city_*" 2>&1',
    # Full backend error logs
    'docker logs soobshio_backend 2>&1 | tail -30',
]:
    print(f'\n$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=20)
    time.sleep(5)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    print(out[:500] if out else '(empty)')
    print('='*50)
ssh.close()
