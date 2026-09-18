import paramiko

host = "45.153.68.59"
user = "root"
secret = "sf?UQ8AYk*-DB8"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, username=user, password=secret, timeout=10)

# Check running containers and database
cmd = 'docker exec -t soobshio_backend python -c "from services.data_layer.database import SessionLocal; from services.data_layer.models import Report; from datetime import datetime; db = SessionLocal(); r = Report(title=\'Великая Нижневартовская Впадина\', description=\'Обнаружен новый кандидат в филиалы Марианской впадины прямо на перекрестке Мира и Ленина. Местные жители уже начали спуск с аквалангами для поиска коммунального смысла жизни.\', category=\'Дороги\', address=\'перекресток Мира и Ленина\', status=\'pending\', lat=60.943, lng=76.545, created_at=datetime.now(), source=\'tg:test_channel\'); db.add(r); db.commit(); print(\'Report ID inserted:\', r.id)"'

stdin, stdout, stderr = ssh.exec_command(cmd)
print("Stdout:", stdout.read().decode())
print("Stderr:", stderr.read().decode())

ssh.close()
