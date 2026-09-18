import os
import sys
import paramiko
from dotenv import load_dotenv

load_dotenv(r"C:\Soobshio_project\.env")
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()
REMOTE = "/root/citypulse_api"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("45.153.68.59", username="root", password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
sftp = ssh.open_sftp()
sftp.put(
    r"C:\Soobshio_project\scripts\deployment\probe_session_remote.py",
    f"{REMOTE}/probe_session_remote.py",
)
sftp.close()
cmd = f"cd {REMOTE} && docker compose exec -T monitoring python /app/probe_session_remote.py"
_, o, e = ssh.exec_command(cmd, timeout=120)
# copy into container via docker cp instead
ssh.exec_command(f"docker cp {REMOTE}/probe_session_remote.py soobshio_monitoring:/app/probe_session_remote.py")
_, o, e = ssh.exec_command(
    "docker exec soobshio_monitoring python /app/probe_session_remote.py",
    timeout=120,
)
print(o.read().decode())
print(e.read().decode())
ssh.close()
