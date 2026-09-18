#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Clear all old reports from local SQLite and production PostgreSQL DBs."""

import sqlite3
import paramiko

LOCAL_DB = "services/Backend/soobshio.db"
VPS_HOST = "45.153.68.59"
VPS_PORT = 22
VPS_USER = "root"
VPS_PASS = "sf?UQ8AYk*-DB8"

def clear_local_db():
    print("=== OCHISTKA LOKALNOY BD (SQLite) ===")
    conn = sqlite3.connect(LOCAL_DB)
    c = conn.cursor()
    c.execute("DELETE FROM reports;")
    c.execute("DELETE FROM geocoding_cache;")
    conn.commit()
    print("[OK] Deleted all reports and geocoding cache from local SQLite")
    c.execute("SELECT COUNT(*) FROM reports;")
    print("Local reports count:", c.fetchone()[0])
    conn.close()

def clear_prod_db():
    print("\n=== OCHISTKA PRODAKSHN BD (PostgreSQL VPS) ===")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(VPS_HOST, VPS_PORT, VPS_USER, VPS_PASS, timeout=30)
        cmd = 'docker exec -i soobshio_postgres psql -U soobshio -d soobshio -c "TRUNCATE TABLE reports RESTART IDENTITY CASCADE;"'
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8', errors='ignore')
        print("VPS output:", out)
        
        # Restart backend to re-seed fresh clean reports
        ssh.exec_command("cd /opt/soobshio && docker compose restart backend")
        print("[OK] Cleared PostgreSQL reports table and restarted backend")
    except Exception as e:
        print("[ERROR] Failed to clear prod DB:", e)
    finally:
        ssh.close()

if __name__ == "__main__":
    clear_local_db()
    clear_prod_db()
