import os
import paramiko
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(os.getenv("TIMEWEB_IP", "45.153.68.59"), username="root", password=os.getenv("SSH_PASSWORD"))

eleven_key = os.getenv("ELEVENLABS_API_KEY", "")
sfx_key = os.getenv("SFX_ENGINE", "")
fish_key = os.getenv("FISH.AUDIO_API_KEY", "")

keys_to_add = f"""
ELEVENLABS_API_KEY={eleven_key}
SFX_ENGINE={sfx_key}
FISH.AUDIO_API_KEY={fish_key}
"""

cmd = f"""
cat << 'EOF' >> /opt/soobshio/.env
{keys_to_add}
EOF
cd /opt/soobshio && docker compose up -d --force-recreate backend
"""

_, out, err = ssh.exec_command(cmd)
print("OUT:", out.read().decode('utf-8', 'replace'))
print("ERR:", err.read().decode('utf-8', 'replace'))

ssh.close()
