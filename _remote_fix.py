import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')

HOST = '45.153.68.59'
USER = 'root'
PASS = 'sf?UQ8AYk*-DB8'

print('Connecting...')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=30, look_for_keys=False, allow_agent=False)
print('Connected!\n')

commands = [
    ('docker system prune -f --filter until=168h', 120),
    ('docker image prune -f', 120),
    ('df -h', 10),
    ('cd /root/citypulse_api && docker compose up -d --build 2>&1 | tail -20', 600),
    ('cd /root/citypulse_api && docker ps --format "table {{.Names}}\t{{.Status}}"', 10),
    ('curl -s http://127.0.0.1:8000/health', 10),
]

for cmd, timeout in commands:
    print(f'$ {cmd[:100]}')
    print('-' * 60)
    chan = ssh.get_transport().open_session()
    chan.settimeout(timeout)
    chan.exec_command(cmd)
    # Read stdout and stderr as they come
    while not chan.exit_status_ready():
        if chan.recv_ready():
            data = chan.recv(4096).decode('utf-8', errors='replace')
            sys.stdout.write(data)
            sys.stdout.flush()
        if chan.recv_stderr_ready():
            data = chan.recv_stderr(4096).decode('utf-8', errors='replace')
            sys.stdout.write(data)
            sys.stdout.flush()
        time.sleep(0.5)
    # Final read
    if chan.recv_ready():
        sys.stdout.write(chan.recv(4096).decode('utf-8', errors='replace'))
    if chan.recv_stderr_ready():
        sys.stdout.write(chan.recv_stderr(4096).decode('utf-8', errors='replace'))
    print()
    print('=' * 60)

ssh.close()
print('Done!')
