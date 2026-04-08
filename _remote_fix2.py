import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')

HOST = '45.153.68.59'
USER = 'root'
PASS = 'sf?UQ8AYk*-DB8'

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
print('Connected!\n')

# Step 1: Stop everything
for cmd in [
    'cd /root/citypulse_api && docker compose down 2>&1',
    'docker ps -aq | xargs docker rm -f 2>&1',
]:
    print(f'$ {cmd[:80]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=60)
    time.sleep(3)

# Step 2: Start fresh
cmd = 'cd /root/citypulse_api && docker compose up -d --build 2>&1'
print(f'$ {cmd}')
chan = ssh.get_transport().open_session()
chan.settimeout(600)
chan.exec_command(cmd)
while not chan.exit_status_ready():
    if chan.recv_ready():
        sys.stdout.write(chan.recv(4096).decode('utf-8', errors='replace'))
        sys.stdout.flush()
    if chan.recv_stderr_ready():
        sys.stdout.write(chan.recv_stderr(4096).decode('utf-8', errors='replace'))
        sys.stdout.flush()
    time.sleep(1)
if chan.recv_ready():
    sys.stdout.write(chan.recv(4096).decode('utf-8', errors='replace'))
print()
print('=' * 60)

# Step 3: Check
time.sleep(10)
for cmd in [
    'cd /root/citypulse_api && docker ps --format "table {{.Names}}\t{{.Status}}"',
    'curl -s http://127.0.0.1:8000/health',
    'df -h / | tail -1',
]:
    print(f'\n$ {cmd[:80]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    out = stdout.read().decode('utf-8', errors='replace')
    if out:
        print(out.strip())

ssh.close()
print('\nDone!')
