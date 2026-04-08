import os, paramiko, sys

with open(r'c:\Soobshio_project\remote_test_qwen.py', 'r', encoding='utf-8') as f:
    script_content = f.read()

sys.stdout.reconfigure(encoding='utf-8')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('45.153.68.59', username='root', password=os.environ['SSH_PASSWORD'])

print("Uploading Qwen test to remote...")
sftp = ssh.open_sftp()
with sftp.file('/tmp/remote_test_qwen.py', 'w') as f:
    f.write(script_content.encode('utf-8'))
sftp.close()

print("Running...")
chan = ssh.get_transport().open_session()
chan.settimeout(600)
chan.exec_command('python3 /tmp/remote_test_qwen.py')

try:
    while True:
        chunk = chan.recv(8192)
        if not chunk: break
        sys.stdout.buffer.write(chunk)
        sys.stdout.flush()
        
    err_chunk = chan.recv_stderr(8192)
    if err_chunk:
        sys.stderr.buffer.write(err_chunk)
        sys.stderr.flush()
except Exception as e:
    print("Error:", e)

ssh.close()
