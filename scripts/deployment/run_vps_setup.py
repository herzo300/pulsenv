import os
import paramiko
from dotenv import load_dotenv

load_dotenv(".env")
HOST = "45.153.68.59"
USER = "root"
ssh_password = os.getenv("SSH_PASSWORD", "").strip()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect(hostname=HOST, username=USER, password=ssh_password, timeout=15)
    print("Connected. Fixing git and pip installs...")
    
    cmd = """
    docker exec -u root soobshio_backend bash -c "apt-get update && apt-get install -y git"
    docker exec soobshio_backend bash -c "cd /app/services/Backend/agent_reach && pip install -e . --break-system-packages"
    docker exec soobshio_backend bash -c "cd /app/services/Backend/openworker && pip install -e . --break-system-packages"
    """
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=300)
    print("STDOUT:", stdout.read().decode("utf-8"))
    print("STDERR:", stderr.read().decode("utf-8"))
except Exception as e:
    print(f"Error: {e}")
finally:
    ssh.close()
