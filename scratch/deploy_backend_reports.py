import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

# Read local reports.py
with open(r"C:\Soobshio_project\services\Backend\routers\reports.py", "r", encoding="utf-8") as f:
    reports_py = f.read()

sftp = ssh.open_sftp()

# Upload to VPS
with sftp.file("/opt/soobshio/services/Backend/routers/reports.py", "w") as f:
    f.write(reports_py)

sftp.close()

print("Uploaded reports.py to VPS. Restarting soobshio_backend...")

_, out, err = ssh.exec_command("docker restart soobshio_backend")
print(out.read().decode())
print(err.read().decode())

ssh.close()
