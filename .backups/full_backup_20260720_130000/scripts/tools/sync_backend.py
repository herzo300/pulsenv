import os

import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("45.153.68.59", username="root", password=os.environ["SSH_PASSWORD"])
sftp = ssh.open_sftp()

local_backend = r"c:\Soobshio_project\services\Backend\admin_metrics.py"
remote_backend = "/opt/soobshio/services/Backend/admin_metrics.py"

print("Uploading admin_metrics.py...")
with open(local_backend, "rb") as f:
    sftp.putfo(f, remote_backend)

sftp.close()

print("Restarting backend...")
_, stdout, _ = ssh.exec_command("cd /opt/soobshio && docker compose restart backend")
print(stdout.read().decode())
ssh.close()
print("Done!")
