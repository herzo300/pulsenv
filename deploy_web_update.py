"""
Deploy updated web files (HTML/CSS/JS) to Timeweb server.
Uploads all public/ files and backend changes, then rebuilds Docker.
"""
import os
import sys
import paramiko
import zipfile
import tempfile
import glob as globmod
from datetime import datetime
from dotenv import load_dotenv

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

PROJECT_ROOT = r"C:\Soobshio_project"
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = os.getenv("TIMEWEB_IP", "").strip()
USER = os.getenv("TIMEWEB_USER", "root").strip()
PASS = os.getenv("SSH_PASSWORD", "").strip()

if not HOST:
    HOST = input("Timeweb IP: ").strip()
if not PASS:
    import getpass
    PASS = getpass.getpass("SSH password: ").strip()

REMOTE_DIR = "/root/citypulse_api"
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
BACKUP_DIR = f"{REMOTE_DIR}/backup_{TIMESTAMP}"

# Cleanup command
CLEANUP_CMD = "docker system prune -f --filter 'until=168h' && docker image prune -f"
FILES_TO_UPLOAD = []

# All public/ HTML files
for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.html")):
    FILES_TO_UPLOAD.append((f, f"public/{os.path.basename(f)}"))

# All public/ JS files
for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.js")):
    FILES_TO_UPLOAD.append((f, f"public/{os.path.basename(f)}"))

# All public/ CSS files
for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.css")):
    FILES_TO_UPLOAD.append((f, f"public/{os.path.basename(f)}"))

# Backend app and routers
FILES_TO_UPLOAD.append((os.path.join(PROJECT_ROOT, "services", "Backend", "app.py"), "services/Backend/app.py"))
FILES_TO_UPLOAD.append((os.path.join(PROJECT_ROOT, "services", "Backend", "security.py"), "services/Backend/security.py"))

# Compliance service
FILES_TO_UPLOAD.append((os.path.join(PROJECT_ROOT, "services", "compliance_service.py"), "services/compliance_service.py"))

# requirements.txt
FILES_TO_UPLOAD.append((os.path.join(PROJECT_ROOT, "requirements.txt"), "requirements.txt"))

# Docker
FILES_TO_UPLOAD.append((os.path.join(PROJECT_ROOT, "docker-compose.yml"), "docker-compose.yml"))

print(f"\n{'='*60}")
print(f"  Soobshio — Деплой обновлений web")
print(f"  Сервер: {HOST}")
print(f"  Файлов: {len(FILES_TO_UPLOAD)}")
print(f"{'='*60}\n")

try:
    print("Подключение SSH...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15, look_for_keys=True, allow_agent=True)
    print("SSH OK ✓")
    sftp = ssh.open_sftp()

    # Backup current public/
    print(f"\nБэкап текущих файлов → {BACKUP_DIR} ...")
    ssh.exec_command(f"mkdir -p {BACKUP_DIR}/public {BACKUP_DIR}/services/Backend {BACKUP_DIR}/services")
    ssh.exec_command(f"cp -r {REMOTE_DIR}/public {BACKUP_DIR}/ 2>/dev/null || true")

    # Create directories
    ssh.exec_command(f"mkdir -p {REMOTE_DIR}/public {REMOTE_DIR}/services/Backend")

    uploaded = 0
    for local_path, relative_path in FILES_TO_UPLOAD:
        if not os.path.exists(local_path):
            print(f"  [SKIP] {relative_path} — не найден")
            continue

        remote_path = f"{REMOTE_DIR}/{relative_path}"
        # Ensure remote dir exists
        remote_dir_path = os.path.dirname(remote_path)
        try:
            sftp.stat(remote_dir_path)
        except:
            ssh.exec_command(f"mkdir -p {remote_dir_path}")

        size = os.path.getsize(local_path)
        sftp.put(local_path, remote_path)
        print(f"  [OK] {relative_path} ({size:,} bytes)")
        uploaded += 1

    sftp.close()

    print(f"\nЗагружено: {uploaded}/{len(FILES_TO_UPLOAD)} файлов")
    print("\nПересборка и рестарт контейнеров...")

    commands = [
        f"cd {REMOTE_DIR} && {CLEANUP_CMD} 2>&1",
        f"cd {REMOTE_DIR} && docker compose up -d --build backend 2>&1 | tail -5",
        f"cd {REMOTE_DIR} && docker compose restart nginx 2>&1 | tail -3",
        f"cd {REMOTE_DIR} && docker ps --format 'table {{.Names}}\t{{.Status}}' 2>&1",
        f"curl -s http://127.0.0.1:8000/health 2>&1",
    ]

    for cmd in commands:
        print(f"\n  $ {cmd[:80]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
        out = stdout.read().decode('utf-8', errors='replace').strip()
        err = stderr.read().decode('utf-8', errors='replace').strip()
        if out:
            print(f"    {out}")
        if err and "warn" in err.lower():
            print(f"    [WARN] {err}")

    ssh.close()
    print(f"\n{'='*60}")
    print("  ДЕПЛОЙ ЗАВЕРШЁН ✓")
    print(f"{'='*60}")

except paramiko.AuthenticationException:
    print("\n[ERROR] Неверный пароль или ключ SSH!")
except paramiko.SSHException as e:
    print(f"\n[ERROR] SSH ошибка: {e}")
except Exception as e:
    print(f"\n[ERROR] {e}")
