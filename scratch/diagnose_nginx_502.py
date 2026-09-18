import os, paramiko, dotenv, time

dotenv.load_dotenv(r"C:\Soobshio_project\.env")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"), timeout=10)

print("=== 1. NGINX ERROR LOG ===")
stdin, out, err = ssh.exec_command("docker exec soobshio_nginx cat /var/log/nginx/error.log | tail -n 30", timeout=8)
print(out.read().decode('utf-8', 'replace'))

print("=== 2. NGINX CONFIG (upstream/proxy) ===")
stdin, out, err = ssh.exec_command("docker exec soobshio_nginx grep -rn 'upstream\\|proxy_pass\\|server ' /etc/nginx/conf.d/", timeout=8)
print(out.read().decode('utf-8', 'replace'))

print("=== 3. BACKEND CONTAINER STATUS & LOGS ===")
stdin, out, err = ssh.exec_command("docker ps --filter name=soobshio_backend --format '{{.Names}} {{.Status}}'", timeout=5)
print(out.read().decode('utf-8', 'replace'))

stdin, out, err = ssh.exec_command("docker logs --tail 30 soobshio_backend 2>&1", timeout=8)
print(out.read().decode('utf-8', 'replace'))

print("=== 4. NETWORK CONNECTIVITY TEST ===")
stdin, out, err = ssh.exec_command("docker exec soobshio_nginx curl -s -o /dev/null -w '%{http_code}' http://backend:8000/health || echo 'FAILED'", timeout=8)
print("Nginx->Backend /health:", out.read().decode('utf-8', 'replace'))

ssh.close()
print("=== DIAGNOSTICS DONE ===")
