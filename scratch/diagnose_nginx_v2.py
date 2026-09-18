import os, paramiko, dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

cmds = [
    ("NGINX CONF", "cat /opt/soobshio/ops/nginx/conf.d/default.conf | grep -A5 'upstream\\|proxy_pass\\|server ' | head -40"),
    ("BACKEND STATUS", "docker ps --filter name=soobshio_backend --format '{{.Names}} {{.Status}}'"),
    ("BACKEND STDERR", "docker logs --tail 15 soobshio_backend 2>&1 | tail -15"),
    ("NGINX->BACKEND", "docker exec soobshio_nginx sh -c 'curl -s -o /dev/null -w \"%{http_code}\" http://backend:8000/health 2>/dev/null || echo FAIL'"),
]

for label, cmd in cmds:
    print(f"=== {label} ===")
    try:
        channel = ssh.get_transport().open_session()
        channel.settimeout(6)
        channel.exec_command(cmd)
        data = b""
        while True:
            try:
                chunk = channel.recv(4096)
                if not chunk:
                    break
                data += chunk
            except Exception:
                break
        print(data.decode('utf-8', 'replace'))
    except Exception as e:
        print(f"[ERROR]: {e}")

ssh.close()
