import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

_, out, _ = ssh.exec_command('find / -name "docker-compose.yml" 2>/dev/null')
print("=== LOCATIONS OF docker-compose.yml ON VPS ===")
print(out.read().decode())

_, out, _ = ssh.exec_command('docker inspect soobshio_viseron')
print("=== VISERON INSPECT ===")
import json
data = json.loads(out.read().decode())
if data:
    print("State:", data[0].get("State"))
    print("RestartCount:", data[0].get("RestartCount"))
    print("Mounts:", json.dumps(data[0].get("Mounts"), indent=2))

ssh.close()
