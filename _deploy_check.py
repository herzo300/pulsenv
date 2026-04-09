import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
PASS = os.getenv('SSH_PASSWORD','')
print('Connecting...')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
for attempt in range(3):
    try:
        ssh.connect(hostname='45.153.68.59', username='root', password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
        print('Connected!\n')
        break
    except Exception as e:
        print(f'Attempt {attempt+1}: {e}')
        if attempt < 2:
            time.sleep(10)
        else:
            sys.exit(1)

def run(cmd, timeout=30):
    print(f'$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    time.sleep(3)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(out[:400])
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if err and 'warn' not in err.lower()[:20]: print('[ERR]', err[:200])
    print('='*50)
    return out

# Full restart of all services
run('cd /root/citypulse_api && docker compose down 2>&1', 30)
time.sleep(3)
run('cd /root/citypulse_api && docker compose up -d --build 2>&1', 300)
time.sleep(25)

# Status
run('docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"', 10)
run('curl -s http://127.0.0.1/health 2>&1', 10)
run('curl -s http://127.0.0.1/categories 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\'Categories: {len(d.get("categories",[]))}\')" 2>&1', 10)
run('docker logs soobshio_monitoring 2>&1 | tail -10', 10)
run('docker logs soobshio_backend 2>&1 | tail -5', 10)
run('df -h / | tail -1', 5)

ssh.close()
print('\nDEPLOY COMPLETE ✅')
