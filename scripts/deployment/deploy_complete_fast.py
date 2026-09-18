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

print(f"Connecting to {HOST} via SSH...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)
sftp = ssh.open_sftp()

def ensure_remote_dir(r_dir):
    try:
        sftp.stat(r_dir)
    except FileNotFoundError:
        ssh.exec_command(f"mkdir -p {r_dir}")

ensure_remote_dir(f"{REMOTE_DIR}/services")

# 1. Upload root services/*.py
services_dir = PROJECT / "services"
uploaded = 0
for f in services_dir.iterdir():
    if f.is_file() and f.suffix == ".py":
        rf = f"{REMOTE_DIR}/services/{f.name}"
        sftp.put(str(f), rf)
        uploaded += 1

print(f"Uploaded {uploaded} root services/*.py files.")

# 2. Upload subfolders in services (except Frontend)
for sub in ["Backend", "business", "data_layer", "monitoring", "ai", "agent_reach", "infrastructure", "pdf_inspector"]:
    local_sub = services_dir / sub
    if not local_sub.exists():
        continue
    for root, dirs, files in os.walk(local_sub):
        dirs[:] = [d for d in dirs if d not in ["__pycache__", ".pytest_cache", ".git"]]
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

# 3. Core, main.py, docker-compose.yml
for f in ["main.py", "docker-compose.yml", "requirements.txt", "alembic.ini"]:
    lp = PROJECT / f
    if lp.exists():
        sftp.put(str(lp), f"{REMOTE_DIR}/{f}")
        uploaded += 1

core_dir = PROJECT / "core"
if core_dir.exists():
    for root, dirs, files in os.walk(core_dir):
        dirs[:] = [d for d in dirs if d not in ["__pycache__", ".git"]]
        rel = Path(root).relative_to(PROJECT)
        r_dir = f"{REMOTE_DIR}/{rel.as_posix()}"
        ensure_remote_dir(r_dir)
        for name in files:
            if not name.endswith((".pyc", ".pyo")):
                sftp.put(str(Path(root) / name), f"{r_dir}/{name}")
                uploaded += 1

sftp.close()
print(f"Total uploaded files: {uploaded} ✓")

print("\nRestarting Docker Backend on VPS...")
commands = [
    f"cd {REMOTE_DIR} && docker compose restart backend",
    "sleep 3",
    "docker compose -f /opt/soobshio/docker-compose.yml ps backend",
    "curl -s http://127.0.0.1:8000/health",
    "curl -s http://127.0.0.1:8000/api/v1/3d-twin/stats",
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
print("  COMPLETE DEPLOY & VERIFY FINISHED! ✓")
print("=" * 60)
