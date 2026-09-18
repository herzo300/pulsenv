import os
import time
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

time.sleep(10)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

print("=== FINAL DOCKER PS CHECK ===")
_, out, _ = ssh.exec_command('docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"')
print(out.read().decode())

print("=== VISERON LOGS (last 20 lines) ===")
_, out, _ = ssh.exec_command('docker logs --tail 20 soobshio_viseron')
print(out.read().decode())

ssh.close()
