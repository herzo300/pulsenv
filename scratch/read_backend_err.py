import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

_, out, err = ssh.exec_command("docker logs --tail 50 soobshio_backend")
print("=== OUT ===")
print(out.read().decode('utf-8', 'replace'))
print("=== ERR ===")
print(err.read().decode('utf-8', 'replace'))

ssh.close()
