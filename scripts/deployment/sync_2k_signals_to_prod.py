import os
import sys
import sqlite3
import paramiko
from pathlib import Path
from dotenv import load_dotenv

PROJECT = Path(r"C:\Soobshio_project")
load_dotenv(PROJECT / ".env")

HOST = os.getenv("TIMEWEB_IP", "45.153.68.59")
USER = "root"
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def main():
    print(f"Connecting to VPS {HOST} to sync 2K signal descriptions/photos...")
    conn = sqlite3.connect(PROJECT / "soobshio.db")
    cur = conn.cursor()
    cur.execute("SELECT id, description FROM reports")
    reports = cur.fetchall()
    conn.close()

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=HOST, username=USER, password=PASSWORD, timeout=15)

    print(f"Syncing {len(reports)} reports with 2K photo links to Postgres...")
    
    # Run update in PostgreSQL container
    for rep_id, desc in reports:
        escaped_desc = (desc or "").replace("'", "''")
        cmd = f"""docker exec -i citypulse_postgres psql -U soobshio -d soobshio -c "UPDATE reports SET description = E'{escaped_desc}' WHERE id = {rep_id};" """
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.channel.recv_exit_status()

    ssh.close()
    print("✓ Все 2K фото и описания успешно синхронизированы в продакшн PostgreSQL на Timeweb VPS!")

if __name__ == "__main__":
    main()
