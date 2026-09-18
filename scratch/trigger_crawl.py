import os, paramiko, dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

print("=== TRIGGERING MONITOR CRAWL ===")
ch = ssh.get_transport().open_session()
ch.settimeout(30)
ch.exec_command("docker exec soobshio_backend curl -s -X POST http://127.0.0.1:8000/api/dispatcher/trigger-crawl")
data = b""
while True:
    try:
        chunk = ch.recv(8192)
        if not chunk: break
        data += chunk
    except: break
print("Trigger result:", data.decode('utf-8', 'replace'))

ssh.close()
