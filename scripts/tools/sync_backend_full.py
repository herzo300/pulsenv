import os

import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect("45.153.68.59", username="root", password=os.environ["SSH_PASSWORD"])
sftp = ssh.open_sftp()


def sync_dir(local_dir, remote_dir):
    try:
        sftp.mkdir(remote_dir)
    except OSError:
        pass  # Directory already exists
    for item in os.listdir(local_dir):
        l_path = os.path.join(local_dir, item)
        r_path = f"{remote_dir}/{item}"
        if os.path.isfile(l_path):
            print(f"Syncing {l_path} -> {r_path}")
            sftp.put(l_path, r_path)
        elif os.path.isdir(l_path) and item != "__pycache__":
            sync_dir(l_path, r_path)


# Syncing the entire Backend service to ensure all new routers and logic are present
sync_dir(r"c:\Soobshio_project\services\Backend", "/opt/soobshio/services/Backend")

sftp.close()

print("Restarting backend...")
_, stdout, _ = ssh.exec_command(
    "cd /opt/soobshio && docker compose up -d --build backend"
)
print(stdout.read().decode())

ssh.close()
print("Success!")
