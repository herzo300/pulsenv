# scratch/remote_clean_vps.py
import paramiko

HOST = "45.153.68.59"
USER = "root"
PASS = "sf?UQ8AYk*-DB8"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)

cmds = [
    "docker exec soobshio_nginx nginx -s reload",
    "curl -v -k https://127.0.0.1/api/health",
    "curl -v -k https://45-153-68-59.sslip.io/api/health",
]

for cmd in cmds:
    print(f"\n--- {cmd} ---")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    out = stdout.read().decode("utf-8", errors="ignore").strip()
    err = stderr.read().decode("utf-8", errors="ignore").strip()
    clean_out = (out + "\n" + err).encode("ascii", errors="replace").decode("ascii")
    print(clean_out)

ssh.close()
