"""Check LiteLLM logs."""
import os, paramiko
from dotenv import load_dotenv
load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=os.getenv("TIMEWEB_IP"), username="root", password=os.getenv("SSH_PASSWORD"))

print("=== LiteLLM Logs ===", flush=True)
_, so, _ = ssh.exec_command("docker logs soobshio_litellm --tail 50")
print(so.read().decode(), flush=True)

ssh.close()
