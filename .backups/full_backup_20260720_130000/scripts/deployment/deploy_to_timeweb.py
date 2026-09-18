"""
Deploy updated project files to Timeweb server via SFTP.
Uses TIMEWEB_TOKEN from .env for reference, SSH password from user input.
"""

import getpass
import os
import sys

import paramiko
from dotenv import load_dotenv

if sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT_ROOT = r"C:\Soobshio_project"
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = "45.153.68.59"
USER = "root"
REMOTE_DIR = "/opt/soobshio"

print("=" * 60)
print("  Soobshio — Деплой на Timeweb (45.153.68.59)")
print("=" * 60)
print()

# Try password first, then key
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

connected = False

# Try password from .env
ssh_password = os.getenv("SSH_PASSWORD", "").strip()

if ssh_password:
    print(f"Подключение по паролю из .env ({len(ssh_password)} символов)...")
    try:
        ssh.connect(
            hostname=HOST,
            username=USER,
            password=ssh_password,
            timeout=15,
            look_for_keys=False,
            allow_agent=False,
            banner_timeout=30,
        )
        print("Подключение по паролю успешно! ✓\n")
        connected = True
    except paramiko.AuthenticationException:
        print("Пароль не подошёл. Проверьте SSH_PASSWORD в .env\n")
    except Exception as e:
        print(f"Ошибка подключения: {e}\n")

if not connected:
    print("\nВведите SSH-пароль вручную:")
    try:
        ssh_password = getpass.getpass(f"Пароль для {USER}@{HOST}: ")
    except (EOFError, KeyboardInterrupt):
        print("\nПароль не введён. Отмена.")
        sys.exit(1)

    if not ssh_password:
        print("Пароль не введён. Отмена.")
        sys.exit(1)

    try:
        print("\nПодключение SSH...")
        ssh.connect(
            hostname=HOST,
            username=USER,
            password=ssh_password,
            timeout=15,
            look_for_keys=False,
            allow_agent=False,
        )
        print("SSH OK ✓\n")
    except paramiko.AuthenticationException:
        print("\n[ERROR] Неверный пароль!")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)

# Files to deploy
files = []

# Public HTML/JS/CSS
import glob as globmod

for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.html")):
    files.append((f, f"public/{os.path.basename(f)}"))
for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.js")):
    files.append((f, f"public/{os.path.basename(f)}"))
for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.css")):
    files.append((f, f"public/{os.path.basename(f)}"))
# for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "*.apk")):
#     files.append((f, f"public/{os.path.basename(f)}"))
for f in globmod.glob(os.path.join(PROJECT_ROOT, "public", "sounds", "*.mp3")):
    files.append((f, f"public/sounds/{os.path.basename(f)}"))

# Backend & Data (recursive walk of python backend directories)
for folder in ["core", "services", "alembic", "data", "scripts"]:
    folder_path = os.path.join(PROJECT_ROOT, folder)
    if os.path.exists(folder_path):
        for root, dirs, filenames in os.walk(folder_path):
            # Exclude Flutter client app and compiled python cache
            path_parts = root.split(os.sep)
            if "Frontend" in path_parts or "__pycache__" in path_parts:
                continue
            for filename in filenames:
                local_path = os.path.join(root, filename)
                rel_path = os.path.relpath(local_path, PROJECT_ROOT)
                # Normalize path separators for Linux remote
                remote_rel = rel_path.replace(os.sep, "/")
                files.append((local_path, remote_rel))

# Single root configuration and runner files
single_files = [
    "main.py",
    "start_all_monitoring.py",
    "start_camera_probe.py",
    "requirements.txt",
    "docker-compose.yml",
    "alembic.ini",
]
for f in single_files:
    local_path = os.path.join(PROJECT_ROOT, f)
    if os.path.exists(local_path):
        files.append((local_path, f))

print(f"Файлов для загрузки: {len(files)}")
print()

sftp = ssh.open_sftp()
uploaded = 0
skipped = 0

for local_path, remote_rel in files:
    if not os.path.exists(local_path):
        print(f"  [SKIP] {remote_rel} — не найден")
        skipped += 1
        continue

    remote_path = f"{REMOTE_DIR}/{remote_rel}"
    remote_dir_path = os.path.dirname(remote_path)

    # Ensure remote directory exists
    try:
        sftp.stat(remote_dir_path)
    except FileNotFoundError:
        stdin, stdout, stderr = ssh.exec_command(f"mkdir -p {remote_dir_path}")
        stdout.channel.recv_exit_status()

    size = os.path.getsize(local_path)
    sftp.put(local_path, remote_path)
    if remote_path.endswith(".sh"):
        stdin, stdout, stderr = ssh.exec_command(f"sed -i 's/\\r$//' {remote_path}")
        stdout.channel.recv_exit_status()
    print(f"  [OK] {remote_rel} ({size:,} b)")
    uploaded += 1

sftp.close()

print(f"\nЗагружено: {uploaded}, Пропущено: {skipped}")
print("\nПерезапуск контейнеров...")

commands = [
    f"docker system prune -af || true",
    f"rm -rf {REMOTE_DIR}/public/*.apk || true",
    f"cd {REMOTE_DIR} && docker compose up -d --build postgres redis backend nginx 2>&1 | tail -15",
    f"docker exec soobshio_nginx nginx -s reload || true",
    f"chmod +x {REMOTE_DIR}/scripts/deployment/bootstrap_production.sh 2>/dev/null || true",
    f"bash {REMOTE_DIR}/scripts/deployment/bootstrap_production.sh {REMOTE_DIR} 2>&1 | tail -30",
    f"cd {REMOTE_DIR} && docker compose exec -T backend python scripts/geocode_all_houses_direct.py",
]

for cmd in commands:
    label = cmd[:70]
    print(f"\n  $ {label}...")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    if out:
        for line in out.split("\n"):
            print(f"    {line}")
    if err and "error" in err.lower():
        print(f"    [ERR] {err}")

ssh.close()

print("\n" + "=" * 60)
print("  ДЕПЛОЙ ЗАВЕРШЁН ✓")
print(f"  http://{HOST}/health")
print(f"  http://{HOST}/infographic")
print(f"  http://{HOST}/map")
print(f"  http://{HOST}/cameras")
print(f"  http://{HOST}/city-dashboard")
print("=" * 60)
