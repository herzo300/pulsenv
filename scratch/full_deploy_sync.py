import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

vps_ip = os.getenv("TIMEWEB_IP", "45.153.68.59")
vps_pass = os.getenv("SSH_PASSWORD")

print(f"=== CONNECTING TO PRODUCTION VPS ({vps_ip}) ===")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(vps_ip, username="root", password=vps_pass)

sftp = ssh.open_sftp()

files_to_sync = [
    (r"C:\Soobshio_project\docker-compose.yml", "/opt/soobshio/docker-compose.yml"),
    (r"C:\Soobshio_project\ops\viseron\config\config.yaml", "/opt/soobshio/ops/viseron/config/config.yaml"),
    (r"C:\Soobshio_project\services\Backend\routers\reports.py", "/opt/soobshio/services/Backend/routers/reports.py"),
    (r"C:\Soobshio_project\services\Backend\app.py", "/opt/soobshio/services/Backend/app.py"),
]

for local_path, remote_path in files_to_sync:
    print(f"Uploading {local_path} -> {remote_path}...")
    remote_dir = os.path.dirname(remote_path)
    # Ensure remote dir exists
    ssh.exec_command(f"mkdir -p {remote_dir}")
    sftp.put(local_path, remote_path)

# Also copy reports.py inside running backend container
sftp.put(r"C:\Soobshio_project\services\Backend\routers\reports.py", "/tmp/reports.py")
sftp.close()

print("Syncing backend container internal files...")
ssh.exec_command("docker cp /tmp/reports.py soobshio_backend:/app/services/Backend/routers/reports.py")

print("Restarting docker-compose services...")
stdin, stdout, stderr = ssh.exec_command("cd /opt/soobshio && docker compose up -d --build")
print("STDOUT:", stdout.read().decode('utf-8', 'replace'))
print("STDERR:", stderr.read().decode('utf-8', 'replace'))

ssh.close()
print("=== DEPLOYMENT SYNC COMPLETED ===")
