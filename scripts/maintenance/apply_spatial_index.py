#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply spatial composite index to production PostgreSQL database on VPS."""

import paramiko

VPS_HOST = "45.153.68.59"
VPS_PORT = 22
VPS_USER = "root"
VPS_PASS = "sf?UQ8AYk*-DB8"

def apply_spatial_index():
    print("=== COZDANIE SPATIAL INDEKSA V POSTGRESQL (VPS) ===")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(VPS_HOST, VPS_PORT, VPS_USER, VPS_PASS, timeout=30)
        sql = "CREATE INDEX IF NOT EXISTS idx_reports_spatial_cat ON reports (lat, lng, category, status);"
        cmd = f'docker exec -i soobshio_postgres psql -U soobshio -d soobshio -c "{sql}"'
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.channel.recv_exit_status()
        out = stdout.read().decode('utf-8', errors='ignore')
        print("VPS Output:", out)
        print("[OK] Index idx_reports_spatial_cat created successfully!")
    except Exception as e:
        print("[ERROR] Failed to create index:", e)
    finally:
        ssh.close()

if __name__ == "__main__":
    apply_spatial_index()
