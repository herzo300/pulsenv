import paramiko

host = "45.153.68.59"
user = "root"
secret = "sf?UQ8AYk*-DB8"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(host, username=user, password=secret, timeout=10)

# Check running containers and database
cmd = 'docker exec -t soobshio_backend python -c "from services.data_layer.database import SessionLocal; from services.data_layer.models import Report; db = SessionLocal(); print(\'Reports count:\', db.query(Report).count())"'

stdin, stdout, stderr = ssh.exec_command(cmd)
print("Stdout:", stdout.read().decode())
print("Stderr:", stderr.read().decode())

ssh.close()
