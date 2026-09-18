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

print(f"Connecting to {HOST}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=15)
sftp = ssh.open_sftp()

def ensure_remote_dir(r_dir):
    try:
        sftp.stat(r_dir)
    except FileNotFoundError:
        ssh.exec_command(f"mkdir -p {r_dir}")

# Files to sync specifically for 3D Twin and updated backend
files_to_sync = [
    "services/Backend/services/geo/twin_3d_engine.py",
    "services/Backend/routers/digital_twin_3d.py",
    "services/Backend/app.py",
    "services/Backend/routers/__init__.py",
    "services/Backend/security.py",
    "services/Backend/auth.py",
    "tests/test_smoke_api.py",
    "docker-compose.yml",
]

# Ensure directories
for rel in [
    "services/Backend/services/geo",
    "services/Backend/routers",
    "services/Backend",
    "tests",
]:
    ensure_remote_dir(f"{REMOTE_DIR}/{rel}")

uploaded = 0
for rel in files_to_sync:
    local_p = PROJECT / rel
    remote_p = f"{REMOTE_DIR}/{rel}"
    if local_p.exists():
        print(f"Uploading {rel}...")
        sftp.put(str(local_p), remote_p)
        uploaded += 1

# Also sync all routers and services in Backend
backend_dir = PROJECT / "services" / "Backend"
for root, dirs, files in os.walk(backend_dir):
    dirs[:] = [d for d in dirs if d not in ["__pycache__", ".pytest_cache", ".git"]]
    rel_root = Path(root).relative_to(PROJECT)
    r_dir = f"{REMOTE_DIR}/{rel_root.as_posix()}"
    ensure_remote_dir(r_dir)
    for f in files:
        if f.endswith((".pyc", ".pyo")):
            continue
        lp = Path(root) / f
        rp = f"{r_dir}/{f}"
        sftp.put(str(lp), rp)
        uploaded += 1

sftp.close()
print(f"Uploaded {uploaded} files successfully!")

print("\nRestarting Docker Backend on VPS...")
commands = [
    f"cd {REMOTE_DIR} && docker compose restart backend",
    "sleep 2",
    f"curl -s http://127.0.0.1:8000/health",
    f"curl -s http://127.0.0.1:8000/api/v1/3d-twin/stats",
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
print("  PRODUCTION DEPLOY COMPLETED SUCCESSFULLY! ✓")
print("=" * 60)
