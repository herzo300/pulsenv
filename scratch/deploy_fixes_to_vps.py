import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

# Read local config.yaml
with open(r"C:\Soobshio_project\ops\viseron\config\config.yaml", "r", encoding="utf-8") as f:
    viseron_cfg = f.read()

# Read local docker-compose.yml
with open(r"C:\Soobshio_project\docker-compose.yml", "r", encoding="utf-8") as f:
    compose_yml = f.read()

# Upload to VPS
sftp = ssh.open_sftp()

# Ensure directories exist
ssh.exec_command("mkdir -p /opt/soobshio/ops/viseron/config")

with sftp.file("/opt/soobshio/ops/viseron/config/config.yaml", "w") as f:
    f.write(viseron_cfg)

with sftp.file("/opt/soobshio/docker-compose.yml", "w") as f:
    f.write(compose_yml)

sftp.close()

print("Files uploaded to VPS. Now restarting services...")

# Restart viseron & openserp
commands = [
    "cd /opt/soobshio && docker compose up -d --force-recreate viseron openserp",
    "sleep 5",
    "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
]

for cmd in commands:
    _, out, err = ssh.exec_command(cmd)
    print(f"=== CMD: {cmd} ===")
    print(out.read().decode())
    print(err.read().decode())

ssh.close()
