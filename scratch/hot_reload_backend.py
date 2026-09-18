import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

# Copy reports.py directly into running container
with open(r"C:\Soobshio_project\services\Backend\routers\reports.py", "r", encoding="utf-8") as f:
    code = f.read()

sftp = ssh.open_sftp()
with sftp.file("/opt/soobshio/services/Backend/routers/reports.py", "w") as f:
    f.write(code)

with sftp.file("/tmp/reports.py", "w") as f:
    f.write(code)

sftp.close()

# Copy to container /app/services/Backend/routers/reports.py and restart
cmd = "docker cp /tmp/reports.py soobshio_backend:/app/services/Backend/routers/reports.py && docker restart soobshio_backend"
_, out, err = ssh.exec_command(cmd)
print("OUT:", out.read().decode())
print("ERR:", err.read().decode())

ssh.close()
