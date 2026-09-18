#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Deploy backend code and fix PostgreSQL database duplicates on Timeweb Cloud VPS."""

import paramiko
import sys
import os

VPS_HOST = "45.153.68.59"
VPS_PORT = 22
VPS_USER = "root"
VPS_PASS = "sf?UQ8AYk*-DB8"

def deploy():
    print("=== CONNECTING TO VPS VIA SSH/SFTP ===")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(VPS_HOST, VPS_PORT, VPS_USER, VPS_PASS, timeout=30)
        print("[OK] Connected to VPS")

        sftp = ssh.open_sftp()

        # Files to upload
        files_to_upload = [
            ("services/Backend/routers/map_data.py", "/opt/soobshio/services/Backend/routers/map_data.py"),
            ("services/Backend/comprehensive_marker_geofix.py", "/opt/soobshio/services/Backend/comprehensive_marker_geofix.py"),
        ]

        for local_p, remote_p in files_to_upload:
            if os.path.exists(local_p):
                print(f"Uploading {local_p} -> {remote_p} ...")
                sftp.put(local_p, remote_p)
                print(f"[OK] Uploaded {local_p}")

        sftp.close()

        # Run Postgres cleanup & rebuild docker backend container
        commands = [
            # Deduplicate PostgreSQL reports table
            'docker exec -i soobshio_postgres psql -U soobshio -d soobshio -c "DELETE FROM reports WHERE id IN (SELECT id FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(address)), LOWER(TRIM(category)) ORDER BY id) as rnum FROM reports WHERE address IS NOT NULL AND address != \'\') t WHERE t.rnum > 1);"',
            # Restart backend container
            "cd /opt/soobshio && docker compose restart backend",
        ]

        for cmd in commands:
            print(f"Executing remote: {cmd}")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            exit_code = stdout.channel.recv_exit_status()
            out_str = stdout.read().decode('utf-8', errors='ignore')
            err_str = stderr.read().decode('utf-8', errors='ignore')
            print(f"Output: {out_str}")
            if err_str:
                print(f"Stderr: {err_str}")

        print("[OK] Backend deployment and DB cleanup completed successfully!")

    except Exception as e:
        print(f"[ERROR] Deployment failed: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    deploy()
