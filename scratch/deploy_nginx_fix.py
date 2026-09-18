import os, paramiko, dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

# Upload the fixed nginx locations include
sftp = ssh.open_sftp()
local_file = r"C:\Soobshio_project\ops\timeweb\soobshio-locations.inc"
remote_file = "/opt/soobshio/ops/timeweb/soobshio-locations.inc"
sftp.put(local_file, remote_file)
sftp.close()
print(f"Uploaded {local_file} -> {remote_file}")

# Validate nginx config
channel = ssh.get_transport().open_session()
channel.settimeout(8)
channel.exec_command("docker exec soobshio_nginx nginx -t 2>&1")
data = b""
while True:
    try:
        chunk = channel.recv(4096)
        if not chunk: break
        data += chunk
    except: break

# Also get stderr
try:
    data += channel.recv_stderr(4096)
except: pass

result = data.decode('utf-8', 'replace')
print("Nginx config test:", result)

if "syntax is ok" in result.lower() or "test is successful" in result.lower() or not result.strip():
    # Reload nginx
    ch2 = ssh.get_transport().open_session()
    ch2.settimeout(5)
    ch2.exec_command("docker exec soobshio_nginx nginx -s reload && echo RELOADED")
    d2 = b""
    while True:
        try:
            chunk = ch2.recv(4096)
            if not chunk: break
            d2 += chunk
        except: break
    print("Nginx reload:", d2.decode('utf-8', 'replace'))
else:
    print("ERROR: Nginx config test failed, NOT reloading")

ssh.close()
