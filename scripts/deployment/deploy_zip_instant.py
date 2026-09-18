import os
import sys
import zipfile
import tempfile
from pathlib import Path
import paramiko
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(r"C:\Soobshio_project")
load_dotenv(PROJECT / ".env")

HOST = "45.153.68.59"
USER = "root"
REMOTE_DIR = "/opt/soobshio"
PASS = os.getenv("SSH_PASSWORD", "").strip()

if not PASS:
    print("[ERROR] SSH_PASSWORD missing in .env")
    sys.exit(1)

print("=" * 60)
print(f"  City Pulse — Мгновенный Zip-деплой на {HOST}")
print("=" * 60)

temp_zip = Path(tempfile.gettempdir()) / "citypulse_deploy.zip"
print("Создание компактного zip архива исходного кода и ассетов...")

with zipfile.ZipFile(temp_zip, "w", zipfile.ZIP_DEFLATED) as zf:
    for folder in ["services", "core", "public", "data", "scripts"]:
        local_dir = PROJECT / folder
        if not local_dir.exists():
            continue
        for root, dirs, files in os.walk(local_dir):
            dirs[:] = [d for d in dirs if d not in ["__pycache__", ".pytest_cache", ".git", "node_modules", "Frontend", "venv", ".venv"]]
            for f in files:
                if f.endswith((".pyc", ".pyo", ".apk")):
                    continue
                lp = Path(root) / f
                arcname = lp.relative_to(PROJECT).as_posix()
                zf.write(lp, arcname)

    for f in ["main.py", "docker-compose.yml", "requirements.txt", "alembic.ini"]:
        lp = PROJECT / f
        if lp.exists():
            zf.write(lp, f)

zip_size_mb = temp_zip.stat().st_size / (1024 * 1024)
print(f"Архив кода готов: {zip_size_mb:.2f} МБ")

print("Подключение к VPS...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)

print("Загрузка архива кода...")
sftp = ssh.open_sftp()
remote_zip = "/tmp/citypulse_deploy.zip"
sftp.put(str(temp_zip), remote_zip)
temp_zip.unlink(missing_ok=True)
print("Архив кода загружен на VPS ✓")

# Upload ARM64 APK if exists
apk_path = PROJECT / "public" / "soobshio_arm64.apk"
if apk_path.exists():
    apk_mb = apk_path.stat().st_size / (1024 * 1024)
    print(f"Загрузка облегченного ARM64 APK ({apk_mb:.1f} МБ)...")
    sftp.put(str(apk_path), f"{REMOTE_DIR}/public/soobshio_arm64.apk")
    sftp.put(str(apk_path), f"{REMOTE_DIR}/public/app-arm64-v8a-release.apk")
    print("APK успешно загружен на VPS ✓")

sftp.close()

print("\nРаспаковка и перезапуск контейнеров...")
remote_commands = [
    f"unzip -o {remote_zip} -d {REMOTE_DIR} && rm -f {remote_zip}",
    f"cd {REMOTE_DIR} && docker compose up -d --no-deps backend nginx",
    "sleep 6",
    "docker ps --format '{{.Names}}: {{.Status}}' | grep soobshio",
    "curl -s -k https://localhost/health || curl -s http://127.0.0.1:8000/health",
]

for cmd in remote_commands:
    print(f"\n$ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=45)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    if out:
        print(out)

ssh.close()
print("\n" + "=" * 60)
print("  ДЕПЛОЙ НА СЕРВЕР ПОЛНОСТЬЮ ЗАВЕРШЁН ✓")
print(f"  Бэкенд Health: http://{HOST}/health")
print(f"  Карта: http://{HOST}/map")
print(f"  Камеры: http://{HOST}/cameras")
print(f"  Скачать ARM64 APK: http://{HOST}/soobshio_arm64.apk")
print("=" * 60)
