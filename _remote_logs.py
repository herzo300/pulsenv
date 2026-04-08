import paramiko, sys, time
sys.stdout.reconfigure(encoding='utf-8')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname='45.153.68.59', username='root', password='sf?UQ8AYk*-DB8', timeout=30, look_for_keys=False, allow_agent=False)

for cmd in [
    'docker logs soobshio_backend 2>&1 | tail -30',
    'docker logs soobshio_ollama 2>&1 | tail -10',
    'cat /root/citypulse_api/.env | grep -E "POSTGRES_PASSWORD|LITELLM_MASTER_KEY" 2>&1',
]:
    print(f'$ {cmd[:80]}')
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    time.sleep(2)
    out = stdout.read().decode('utf-8', errors='replace')
    if out:
        print(out.strip())
    print('='*60)

ssh.close()
