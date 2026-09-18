import os
import sys
import zipfile
import paramiko
from dotenv import load_dotenv

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = os.getenv("TIMEWEB_IP", "45.153.68.59")
USER = "root"
REMOTE_DIR = "/root/citypulse_api"
ARCHIVE_NAME = "deploy_archive.zip"
ARCHIVE_PATH = os.path.join(PROJECT_ROOT, ARCHIVE_NAME)

print("=" * 60)
print(f" Soobshio Full Deploy to Timeweb ({HOST})")
print("=" * 60)

# Directories and files to include
INCLUDE_DIRS = [
    "alembic",
    "backend",
    "core",
    "ops",
    "public",
    "scripts/deployment",
    "session",
    "services",
]
INCLUDE_FILES = [
    "alembic.ini",
    "docker-compose.yml",
    "Dockerfile",
    "requirements.txt",
    "start_all_monitoring.py",
    "start_camera_probe.py",
    "main.py",
    "pride_cams.json",
    "monitoring_session.session",
]

print("\n[1/4] Zipping project files...")
with zipfile.ZipFile(ARCHIVE_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
    for file in INCLUDE_FILES:
        filepath = os.path.join(PROJECT_ROOT, file)
        if os.path.exists(filepath):
            zipf.write(filepath, arcname=file)
    for folder in INCLUDE_DIRS:
        folder_path = os.path.join(PROJECT_ROOT, folder)
        if os.path.exists(folder_path):
            for root, dirs, files in os.walk(folder_path):
                # Optimization: Skip Frontend sources, keep only web build
                rel_path = os.path.relpath(root, PROJECT_ROOT).replace("\\", "/").lower()
                if rel_path.startswith("services/frontend"):
                    target = "services/frontend/build/web"
                    if rel_path != target and not rel_path.startswith(target + "/"):
                        # Prune deeper subfolders to speed up and skip junk
                        dirs[:] = []
                        continue
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, PROJECT_ROOT)
                    zipf.write(file_path, arcname=arcname)

print(f"Archive created: {ARCHIVE_PATH} ({os.path.getsize(ARCHIVE_PATH) / 1024 / 1024:.2f} MB)")

print("\n[2/4] Connecting to server via SSH...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh_password = os.getenv("SSH_PASSWORD", "").strip()

if not ssh_password:
    print("SSH_PASSWORD not found in .env. Exiting.")
    sys.exit(1)

ssh.connect(hostname=HOST, username=USER, password=ssh_password, timeout=15, look_for_keys=False, allow_agent=False)
print("SSH OK [OK]")

print("\n[3/4] Uploading archive...")
sftp = ssh.open_sftp()
try:
    sftp.stat(REMOTE_DIR)
except FileNotFoundError:
    ssh.exec_command(f"mkdir -p {REMOTE_DIR}")

local_env = os.path.join(PROJECT_ROOT, ".env")
if os.path.exists(local_env):
    sftp.put(local_env, f"{REMOTE_DIR}/.env")
    print("  [OK] .env synced to server")

remote_archive = f"{REMOTE_DIR}/{ARCHIVE_NAME}"
sftp.put(ARCHIVE_PATH, remote_archive)
sftp.close()
print("Upload complete. [OK]")

os.remove(ARCHIVE_PATH)

print("\n[4/4] Updating server and restarting Docker...")
commands = [
    f"cd {REMOTE_DIR} && unzip -o {ARCHIVE_NAME}",
    f"cd {REMOTE_DIR} && rm -f {ARCHIVE_NAME}",
    f"chmod +x {REMOTE_DIR}/scripts/deployment/bootstrap_production.sh",
    f"bash {REMOTE_DIR}/scripts/deployment/bootstrap_production.sh {REMOTE_DIR}",
]

for cmd in commands:
    print(f" $ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='ignore').strip()
    if out:
        for line in out.split("\n"):
            safe_line = line.encode('ascii', errors='ignore').decode('ascii')
            print(f"   {safe_line}")
    err = stderr.read().decode('utf-8', errors='ignore').strip()
    if err and "error" in err.lower():
        safe_err = err.encode('ascii', errors='ignore').decode('ascii')
        print(f"   [ERR] {safe_err}")

ssh.close()
print("\n" + "=" * 60)
print(" DEPLOYMENT COMPLETE [OK]")
print("=" * 60)
