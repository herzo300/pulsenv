import os
import sys

import paramiko
from dotenv import load_dotenv

# Ensure stdout uses UTF-8 to prevent charmap errors on Windows
if sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

env_path = r"C:\Soobshio_project\.env"
load_dotenv(env_path)

HOST = os.getenv("TIMEWEB_IP")
USER = os.getenv("TIMEWEB_USER")
PASS = os.getenv("SSH_PASSWORD")

zip_path = r"C:\Users\рс\Desktop\citypulse_timeweb_migration.zip"

if not HOST or not USER or not PASS:
    print("Error: TIMEWEB_IP, TIMEWEB_USER, or SSH_PASSWORD not found in .env!")
    exit(1)

print(f"Starting automated migration to {HOST} with user {USER}...")

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    print("Connecting to SSH...")
    ssh.connect(hostname=HOST, username=USER, password=PASS, timeout=10)
    print("Login successful!")

    sftp = ssh.open_sftp()

    base_remote_path = "/root" if USER == "root" else f"/home/{USER}"
    remote_zip = f"{base_remote_path}/citypulse_timeweb_migration.zip"
    remote_dir = f"{base_remote_path}/citypulse_api"

    print(f"Uploading archive ({os.path.getsize(zip_path) // (1024 * 1024)} MB)...")
    sftp.put(zip_path, remote_zip)
    print("Upload complete!")
    sftp.close()

    print("Unpacking and running Docker Compose...")
    commands = [
        "apt-get update && apt-get install unzip curl gnupg -y",
        # Install Docker if missing
        "if ! command -v docker &> /dev/null; then apt-get install docker.io docker-compose-v2 -y; fi",
        f"rm -rf {remote_dir}",
        f"unzip -o {remote_zip} -d {remote_dir}",
        f"rm {remote_zip}",
        f"cd {remote_dir} && docker compose up -d --build",
    ]

    for cmd in commands:
        print(f"Executing: {cmd}")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        exit_status = stdout.channel.recv_exit_status()

        output = stdout.read().decode("utf-8").strip()
        error = stderr.read().decode("utf-8").strip()

        if output:
            print("LOG: " + output[:500])
        if exit_status != 0 and error:
            print("ERROR: " + error)

    print("=========================================")
    print("MIGRATION COMPLETED SUCCESSFULLY!")
    print(f"Backend API is running on {HOST}:8080")

except Exception as e:
    print(f"Critical error: {e}")
finally:
    ssh.close()
