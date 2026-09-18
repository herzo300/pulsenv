import os

import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("45.153.68.59", username="root", password=os.environ["SSH_PASSWORD"])
# Update docker-compose.yml memory limit to 8G
ssh.exec_command(
    "cd /opt/soobshio && sed -i 's/memory: 6G/memory: 8G/' docker-compose.yml"
)
_, stdout, stderr = ssh.exec_command("cd /opt/soobshio && docker compose up -d ollama")
print(stdout.read().decode())
print(stderr.read().decode())
ssh.close()
