import paramiko
import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(str(Path(__file__).parent / ".env"))

HOST = os.getenv("TIMEWEB_IP", "45.153.68.59")
USER = os.getenv("TIMEWEB_USER", "root")
PASS = os.getenv("SSH_PASSWORD", "")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USER, password=PASS)

def exec_cmd(cmd):
    print(f"> {cmd}")
    _, stdout, stderr = ssh.exec_command(cmd)
    try:
        out = stdout.read().decode('utf-8')
        if out: print(out)
    except: pass
    try:
        err = stderr.read().decode('utf-8')
        if err: print("ERR:", err)
    except: pass

print("Setup PP-Human via Docker on Remote VPS...")

exec_cmd("docker exec soobshio_monitoring bash -c 'mkdir -p /app/models/pphuman_temp'")
# Устанавливаем paddlepaddle для конвертации
exec_cmd("docker exec soobshio_monitoring bash -c 'pip install -q --no-cache-dir paddlepaddle paddle2onnx'")

# Python script to download
dl_script = "import urllib.request; urllib.request.urlretrieve('https://paddleclas.bj.bcebos.com/models/PULC/person_attribute_infer.tar', '/app/models/pphuman_temp/pulc.tar')"
exec_cmd(f"docker exec soobshio_monitoring python -c \"{dl_script}\"")

exec_cmd("docker exec soobshio_monitoring bash -c 'cd /app/models/pphuman_temp && tar -xf pulc.tar'")

cmd_convert = (
    "docker exec soobshio_monitoring bash -c '/home/appuser/.local/bin/paddle2onnx "
    "--model_dir /app/models/pphuman_temp/person_attribute_infer "
    "--model_filename inference.pdmodel "
    "--params_filename inference.pdiparams "
    "--save_file /app/models/pphuman_attribute.onnx "
    "--opset_version 11'"
)
exec_cmd(cmd_convert)

# Убираем временную папку и удаляем огромный paddlepaddle
exec_cmd("docker exec soobshio_monitoring bash -c 'rm -rf /app/models/pphuman_temp'")
exec_cmd("docker exec soobshio_monitoring bash -c 'pip uninstall -y paddlepaddle paddle2onnx'")

# Перезагружаем контейнер
exec_cmd("cd /opt/soobshio && docker compose restart monitoring")
print("OK! PP-Human deployed to Server!")

