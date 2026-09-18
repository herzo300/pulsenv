import paramiko
from datetime import datetime

host = "45.153.68.59"
user = "root"
secret = "sf?UQ8AYk*-DB8"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, username=user, password=secret, timeout=10)

now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# SQLite insert command on VPS
cmd = f"""sqlite3 /opt/soobshio/soobshio.db "INSERT INTO reports (title, description, category, address, status, lat, lng, created_at, source) VALUES ('Великая Нижневартовская Впадина', 'Обнаружен новый кандидат в филиалы Марианской впадины прямо на перекрестке Мира и Ленина. Местные жители уже начали спуск с аквалангами для поиска коммунального смысла жизни.', 'Дороги', 'перекресток Мира и Ленина', 'pending', 60.943, 76.545, '{now_str}', 'tg:test_channel');" """

stdin, stdout, stderr = ssh.exec_command(cmd)
err = stderr.read().decode().strip()
out = stdout.read().decode().strip()

if err:
    print(f"Error executing remote query: {err}")
else:
    print("Remote SQLite insert completed successfully!")

ssh.close()
