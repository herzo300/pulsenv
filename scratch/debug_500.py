import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

_, out, _ = ssh.exec_command('docker exec soobshio_backend python -c "import requests; r = requests.get(\'http://127.0.0.1:8000/api/reports/lost-found/tts?text=test\'); print(r.status_code, r.text)"')
print("=== LOCAL CONTAINER TEST ===")
print(out.read().decode('utf-8', 'replace'))

ssh.close()
