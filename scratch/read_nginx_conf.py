import os, paramiko, dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

cmds = [
    ("NGINX CONF FILES", "ls -la /opt/soobshio/ops/nginx/conf.d/"),
    ("DEFAULT.CONF", "cat /opt/soobshio/ops/nginx/conf.d/default.conf"),
    ("DOCKER COMPOSE NGINX SECTION", "grep -A20 'nginx:' /opt/soobshio/docker-compose.yml"),
]

for label, cmd in cmds:
    print(f"\n=== {label} ===")
    try:
        channel = ssh.get_transport().open_session()
        channel.settimeout(5)
        channel.exec_command(cmd)
        data = b""
        while True:
            try:
                chunk = channel.recv(8192)
                if not chunk:
                    break
                data += chunk
            except Exception:
                break
        print(data.decode('utf-8', 'replace'))
    except Exception as e:
        print(f"[ERROR]: {e}")

ssh.close()
