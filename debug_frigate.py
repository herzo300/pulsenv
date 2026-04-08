"""Deep Frigate debug."""
import os, paramiko
from dotenv import load_dotenv
load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=os.getenv("TIMEWEB_IP"), username="root", password=os.getenv("SSH_PASSWORD"))

print("=== Frigate Config Check ===", flush=True)
_, so, _ = ssh.exec_command("ls -la /root/citypulse_api/ops/frigate/config.yml")
print(so.read().decode(), flush=True)

print("=== Frigate Full Logs ===", flush=True)
_, so, _ = ssh.exec_command("docker logs soobshio_frigate")
print(so.read().decode(), flush=True)

print("=== Frigate Inspect (Env/Mounts) ===", flush=True)
_, so, _ = ssh.exec_command("docker inspect soobshio_frigate --format '{{json .Config.Env}} {{json .Mounts}}'")
print(so.read().decode(), flush=True)

ssh.close()
