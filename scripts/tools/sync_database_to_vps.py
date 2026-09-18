import os
import sys
import paramiko

# Load environment
env_path = r"c:\Soobshio_project\.env"
if os.path.exists(env_path):
    print("Loading .env...")
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ[k] = v.strip().replace('"', '')

ssh_password = os.getenv("SSH_PASSWORD")
timeweb_ip = os.getenv("TIMEWEB_IP", "45.153.68.59")

if not ssh_password:
    print("❌ SSH_PASSWORD is not set in .env")
    sys.exit(1)

print(f"Connecting to VPS at {timeweb_ip}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(timeweb_ip, username="root", password=ssh_password)
sftp = ssh.open_sftp()

local_db = r"c:\Soobshio_project\soobshio.db"
remote_db = "/opt/soobshio/data/soobshio_sync.db"

local_script = r"c:\Soobshio_project\services\Backend\remote_db_sync.py"
remote_script = "/opt/soobshio/data/remote_db_sync.py"

print("Uploading soobshio.db to remote VPS...")
sftp.put(local_db, remote_db)

print("Uploading remote_db_sync.py to remote VPS...")
sftp.put(local_script, remote_script)

sftp.close()

print("Executing database sync inside backend container...")
stdin, stdout, stderr = ssh.exec_command(
    "cd /opt/soobshio && docker compose exec -T backend python /app/data/remote_db_sync.py"
)

out = stdout.read().decode("utf-8", errors="replace")
err = stderr.read().decode("utf-8", errors="replace")

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

print("\n=== Remote execution output ===")
if out:
    print(out)
if err:
    print(err)
print("================================")

ssh.close()
print("Success!")
