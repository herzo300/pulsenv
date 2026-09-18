import os
import sys
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
print(f"  City Pulse — Быстрый деплой на {HOST}")
print("=" * 60)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)
sftp = ssh.open_sftp()

def ensure_remote_dir(r_dir):
    try:
        sftp.stat(r_dir)
    except FileNotFoundError:
        ssh.exec_command(f"mkdir -p {r_dir}")

uploaded = 0
for folder in ["services/Backend", "services/business", "services/data_layer", "services/monitoring", "services/ai", "core", "public", "data"]:
    local_dir = PROJECT / folder
    if not local_dir.exists():
        continue
    for root, dirs, files in os.walk(local_dir):
        dirs[:] = [d for d in dirs if d not in ["__pycache__", ".pytest_cache", ".git", "node_modules", "Frontend"]]
        rel = Path(root).relative_to(PROJECT)
        r_dir = f"{REMOTE_DIR}/{rel.as_posix()}"
        ensure_remote_dir(r_dir)
        for name in files:
            if name.endswith((".pyc", ".pyo")):
                continue
            lp = Path(root) / name
            rp = f"{r_dir}/{name}"
            sftp.put(str(lp), rp)
            uploaded += 1

# Upload single files
for f in ["main.py", "docker-compose.yml", "requirements.txt", "alembic.ini"]:
    lp = PROJECT / f
    if lp.exists():
        sftp.put(str(lp), f"{REMOTE_DIR}/{f}")
        uploaded += 1

sftp.close()
print(f"Загружено файлов: {uploaded} ✓")

print("\nПерезапуск сервисов на VPS...")
commands = [
    f"cd {REMOTE_DIR} && docker compose restart backend nginx",
    "sleep 3",
    "docker ps --format '{{.Names}}: {{.Status}}'",
    "curl -s http://127.0.0.1:8000/health || curl -s http://localhost/health",
]

for cmd in commands:
    print(f"\n$ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace").strip()
    if out:
        print(out)

ssh.close()
print("\n" + "=" * 60)
print("  ДЕПЛОЙ УСПЕШНО ЗАВЕРШЁН ✓")
print("=" * 60)
