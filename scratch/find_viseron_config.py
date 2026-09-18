import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

print("=== VISERON CONTAINER MOUNTS & CONFIG ===")
_, out, _ = ssh.exec_command('docker inspect soobshio_viseron --format "{{json .Mounts}}"')
print(out.read().decode())

print("\n=== FIND VISERON CONFIG ON HOST ===")
_, out, _ = ssh.exec_command('find / -name "viseron" 2>/dev/null; find / -name "config.yaml" 2>/dev/null')
print(out.read().decode())

ssh.close()
