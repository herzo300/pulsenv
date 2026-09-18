import os

import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("45.153.68.59", username="root", password=os.environ["SSH_PASSWORD"])
sftp = ssh.open_sftp()

files_to_sync = [
    (
        r"c:\Soobshio_project\ops\litellm_config.yaml",
        "/opt/soobshio/ops/litellm_config.yaml",
    ),
    (
        r"c:\Soobshio_project\services\zai_service.py",
        "/opt/soobshio/services/zai_service.py",
    ),
    (
        r"c:\Soobshio_project\services\Backend\admin_metrics.py",
        "/opt/soobshio/services/Backend/admin_metrics.py",
    ),
]

for local, remote in files_to_sync:
    print(f"Syncing {local} -> {remote}")
    sftp.put(local, remote)

sftp.close()

print("Restarting services...")
# Restarting litellm to apply config change and backend for code changes
_, stdout, _ = ssh.exec_command(
    "cd /opt/soobshio && docker compose restart litellm backend"
)
print(stdout.read().decode())

ssh.close()
print("Success!")
