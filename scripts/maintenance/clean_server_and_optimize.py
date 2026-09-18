"""
Server deep cleaning and optimization script.
Removes temp files, dangling docker images, trims logs, deploys clean code, and verifies health.
"""
import os
import sys
import tempfile
import zipfile
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
print(f"  City Pulse — Глубокая очистка и оптимизация VPS ({HOST})")
print("=" * 60)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)

# Step 1: Clean server junk
print("\n[1/4] Очистка мусора на сервере (temp, dangling docker, logs)...")
clean_commands = [
    "rm -rf /tmp/citypulse* /tmp/*.zip /tmp/*.apk",
    "docker system prune -f",
    "journalctl --vacuum-time=3d",
    "find /opt/soobshio -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true",
    "find /opt/soobshio -name '*.pyc' -delete 2>/dev/null || true",
    "df -h /",
]

for cmd in clean_commands:
    print(f"$ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    if out:
        print(out)

# Step 2: Build clean code archive
print("\n[2/4] Создание чистого архива кода и ассетов...")
temp_zip = Path(tempfile.gettempdir()) / "citypulse_clean.zip"
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

zip_mb = temp_zip.stat().st_size / (1024 * 1024)
print(f"Архив готов: {zip_mb:.2f} МБ")

# Step 3: Upload and apply
print("\n[3/4] Загрузка чистых файлов на VPS...")
sftp = ssh.open_sftp()
remote_zip = "/tmp/citypulse_clean.zip"
sftp.put(str(temp_zip), remote_zip)
temp_zip.unlink(missing_ok=True)

apk_path = PROJECT / "public" / "soobshio_arm64.apk"
if apk_path.exists():
    apk_mb = apk_path.stat().st_size / (1024 * 1024)
    print(f"Синхронизация ARM64 APK ({apk_mb:.1f} МБ) в public...")
    sftp.put(str(apk_path), f"{REMOTE_DIR}/public/soobshio_arm64.apk")
    sftp.put(str(apk_path), f"{REMOTE_DIR}/public/app-arm64-v8a-release.apk")

sftp.close()

# Step 4: Unpack, restart and verify
print("\n[4/4] Распаковка, перезапуск и проверка здоровья...")
deploy_commands = [
    f"unzip -o {remote_zip} -d {REMOTE_DIR} && rm -f {remote_zip}",
    f"cd {REMOTE_DIR} && docker compose up -d --no-deps backend nginx",
    "sleep 5",
    "docker ps --format '{{.Names}}: {{.Status}}' | grep soobshio",
    "curl -s -k https://localhost/health || curl -s http://127.0.0.1:8000/health",
]

for cmd in deploy_commands:
    print(f"\n$ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=45)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    if out:
        print(out)

ssh.close()
print("\n" + "=" * 60)
print("  СЕРВЕР ПОЛНОСТЬЮ ОЧИЩЕН, ОПТИМИЗИРОВАН И ПЕРЕЗАПУЩЕН ✓")
print("=" * 60)
