import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

_, out, _ = ssh.exec_command('cat /opt/soobshio/docker-compose.yml')
content = out.read().decode('utf-8', 'replace')
with open('scratch/vps_docker_compose.yml', 'w', encoding='utf-8') as f:
    f.write(content)

print("Saved to scratch/vps_docker_compose.yml (length:", len(content), ")")
ssh.close()
