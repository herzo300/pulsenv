import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

vps_ip = os.getenv("TIMEWEB_IP", "45.153.68.59")
vps_pass = os.getenv("SSH_PASSWORD")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(vps_ip, username="root", password=vps_pass)

sftp = ssh.open_sftp()

local_backend = r"C:\Soobshio_project\services\Backend"
remote_backend = "/opt/soobshio/services/Backend"

print("=== SYNCING ENTIRE BACKEND FOLDER TO VPS ===")

for root, dirs, files in os.walk(local_backend):
    rel_path = os.path.relpath(root, local_backend)
    remote_dir = os.path.join(remote_backend, rel_path).replace("\\", "/")
    
    try:
        sftp.mkdir(remote_dir)
    except Exception:
        pass
    
    for f in files:
        if f.endswith(".pyc") or f.startswith("."):
            continue
        local_file = os.path.join(root, f)
        remote_file = os.path.join(remote_dir, f).replace("\\", "/")
        sftp.put(local_file, remote_file)
        print(f"Synced {f} -> {remote_file}")

sftp.close()

print("=== REBUILDING SOOBSHIO_BACKEND CONTAINER ===")
cmd = "cd /opt/soobshio && docker compose build backend && docker compose up -d backend"
_, out, err = ssh.exec_command(cmd)
print("STDOUT:", out.read().decode('utf-8', 'replace'))
print("STDERR:", err.read().decode('utf-8', 'replace'))

ssh.close()
print("=== BACKEND SYNC COMPLETE ===")
