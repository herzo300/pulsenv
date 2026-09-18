import paramiko, os
from dotenv import load_dotenv

load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password=os.getenv('SSH_PASSWORD'))

commands = [
    "docker compose -f /opt/soobshio/docker-compose.yml up -d --force-recreate backend",
    "sleep 4",
    "docker compose -f /opt/soobshio/docker-compose.yml ps backend",
    "docker compose -f /opt/soobshio/docker-compose.yml logs --tail 25 backend",
    "curl -s http://127.0.0.1:8000/health",
    "curl -s http://127.0.0.1:8000/api/v1/3d-twin/stats"
]

for cmd in commands:
    print(f"\n>>> {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=40)
    stdout.channel.recv_exit_status()
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    if out:
        print("OUT:\n", out)
    if err:
        print("ERR:\n", err)

ssh.close()
