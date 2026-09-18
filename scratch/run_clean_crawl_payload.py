import os, paramiko, dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

py_code = """
import urllib.request, json
req = urllib.request.Request('http://127.0.0.1:8000/api/reports/clean-and-crawl', data=b'{}', headers={'Content-Type': 'application/json'}, method='POST')
try:
    with urllib.request.urlopen(req) as resp:
        print(resp.read().decode('utf-8'))
except Exception as e:
    print('Clean & crawl trigger err:', e)
"""

ch = ssh.get_transport().open_session()
ch.settimeout(30)
ch.exec_command(f'docker exec soobshio_backend python -c "{py_code}"')
data = b""
while True:
    try:
        chunk = ch.recv(8192)
        if not chunk: break
        data += chunk
    except: break
print("Crawl result:", data.decode('utf-8', 'replace'))

ssh.close()
