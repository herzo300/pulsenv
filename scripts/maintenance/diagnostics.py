import os, paramiko, sys

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('45.153.68.59', username='root', password=os.environ['SSH_PASSWORD'])

def rc(cmd):
    _, out, _ = ssh.exec_command(cmd)
    return out.read().decode('utf-8', 'replace').strip()

print('--- DOCKER CONTAINERS ---')
print(rc('docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'))

print('\n--- SYSTEM RESOURCES ---')
print(rc('free -h'))
print(rc('uptime'))

print('\n--- OLLAMA CPU/MEM STATS ---')
print(rc('docker stats --no-stream soobshio_ollama soobshio_backend soobshio_postgres soobshio_litellm'))

print('\n--- API HEALTH CHECK ---')
print('Backend /health:', rc('curl -s http://127.0.0.1:8000/health || echo "FAILED"'))
print('SmolVLM /health:', rc('curl -s http://127.0.0.1:8090/health || echo "FAILED"'))
print('LiteLLM /health:', rc('curl -s http://127.0.0.1:4000/health || echo "FAILED"'))

ssh.close()
