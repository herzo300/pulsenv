import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
from dotenv import load_dotenv; import os
load_dotenv(r'c:\Soobshio_project\.env')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD',''), timeout=30, look_for_keys=False, allow_agent=False)

# Wait for nginx
time.sleep(15)

print('=== FULL SERVICE STATUS ===\n')
for cmd in [
    'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"',
    'curl -s http://127.0.0.1/health 2>&1',
    'curl -s http://127.0.0.1/categories 2>&1 | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f\"  {c.get(chr(105)+chr(100),chr(63))}: {c.get(chr(110)+chr(97)+chr(109)+chr(101),chr(63))}\") for c in d.get(chr(99)+chr(97)+chr(116)+chr(101)+chr(103)+chr(111)+chr(114)+chr(105)+chr(101)+chr(115),[])]"',
    'curl -s http://127.0.0.1/map 2>&1 | head -3',
    'docker logs soobshio_monitoring 2>&1 | tail -15',
    'docker logs soobshio_camera_probe 2>&1 | tail -5',
]:
    print(f'$ {cmd[:70]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    time.sleep(3)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    if out: print(out[:500])
    print('='*60)
ssh.close()
