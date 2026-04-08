import os, sys, paramiko, glob as globmod

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

PROJECT = r'C:\Soobshio_project'
HOST = '45.153.68.59'
USER = 'root'
REMOTE_DIR = '/root/citypulse_api'

# Read password directly from .env
with open(os.path.join(PROJECT, '.env'), 'r', encoding='utf-8') as f:
    for line in f:
        if line.startswith('SSH_PASSWORD='):
            PASS = line.split('=', 1)[1].strip()
            break

if not PASS:
    print('[ERROR] SSH_PASSWORD not found in .env')
    sys.exit(1)

print(f'SSH пароль: {PASS[:3]}...({len(PASS)} символов)')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15, look_for_keys=False, allow_agent=False)
print('SSH OK ✓')

# Collect files
files = []
for f in globmod.glob(os.path.join(PROJECT, 'public', '*.html')):
    files.append((f, f'public/{os.path.basename(f)}'))
for f in globmod.glob(os.path.join(PROJECT, 'public', '*.js')):
    files.append((f, f'public/{os.path.basename(f)}'))
for f in globmod.glob(os.path.join(PROJECT, 'public', '*.css')):
    files.append((f, f'public/{os.path.basename(f)}'))

backend_files = [
    ('services/Backend/app.py', 'services/Backend/app.py'),
    ('services/Backend/security.py', 'services/Backend/security.py'),
    ('services/Backend/routers/map_data.py', 'services/Backend/routers/map_data.py'),
    ('services/Backend/routers/uk_ratings.py', 'services/Backend/routers/uk_ratings.py'),
    ('services/uk_service.py', 'services/uk_service.py'),
    ('services/compliance_service.py', 'services/compliance_service.py'),
    ('requirements.txt', 'requirements.txt'),
    ('docker-compose.yml', 'docker-compose.yml'),
]
for local_rel, remote_rel in backend_files:
    lp = os.path.join(PROJECT, local_rel)
    if os.path.exists(lp):
        files.append((lp, remote_rel))

print(f'Файлов для загрузки: {len(files)}')
print()

sftp = ssh.open_sftp()
uploaded = 0
for lp, rr in files:
    if not os.path.exists(lp):
        print(f'  [SKIP] {rr}')
        continue
    rd = os.path.dirname(f'{REMOTE_DIR}/{rr}')
    try:
        sftp.stat(rd)
    except Exception:
        stdin, stdout, stderr = ssh.exec_command(f'mkdir -p {rd}')
        stdout.channel.recv_exit_status()
    sz = os.path.getsize(lp)
    sftp.put(lp, f'{REMOTE_DIR}/{rr}')
    print(f'  [OK] {rr} ({sz:,} b)')
    uploaded += 1
sftp.close()

print(f'\nЗагружено: {uploaded} файлов')
print('\nРестарт контейнеров...')

commands = [
    f'cd {REMOTE_DIR} && docker compose up -d --build backend 2>&1 | tail -10',
    f'cd {REMOTE_DIR} && docker compose restart nginx 2>&1 | tail -5',
    'sleep 3 && docker ps --format "table {{.Names}}\t{{.Status}}" 2>&1',
    'curl -s http://127.0.0.1:8000/health 2>&1',
]

for cmd in commands:
    print(f'  $ {cmd[:70]}...')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
    exit_code = stdout.channel.recv_exit_status()
    result = stdout.read().decode('utf-8', errors='replace').strip()
    if result:
        for line in result.split('\n'):
            print(f'    {line}')
    e = stderr.read().decode('utf-8', errors='replace').strip()
    if e and 'error' in e.lower():
        print(f'    [ERR] {e}')

ssh.close()
print('\n' + '=' * 60)
print('  ДЕПЛОЙ ЗАВЕРШЁН ✓')
print(f'  http://{HOST}/health')
print(f'  http://{HOST}/infographic')
print(f'  http://{HOST}/map')
print(f'  http://{HOST}/cameras')
print(f'  http://{HOST}/city-dashboard')
print('=' * 60)
