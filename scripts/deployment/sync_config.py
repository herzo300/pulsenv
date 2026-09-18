import os, paramiko

config_path = r'c:\Soobshio_project\ops\litellm_config.yaml'
with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('45.153.68.59', username='root', password=os.environ['SSH_PASSWORD'])

sftp = ssh.open_sftp()
with sftp.file('/opt/soobshio/ops/litellm_config.yaml', 'w') as f:
    f.write(content.encode('utf-8'))
sftp.close()

print("Restarting litellm...")
_, stdout, _ = ssh.exec_command("cd /opt/soobshio && docker compose restart litellm")
print(stdout.read().decode())
ssh.close()
print("Success!")
