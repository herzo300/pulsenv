# scripts/maintenance/force_start_backend.py
import paramiko
import time

def main():
    print("=== FORCE STARTING BACKEND CONTAINER ON VPS ===")
    host = "45.153.68.59"
    username = "root"
    password = "sf?UQ8AYk*-DB8"
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(host, 22, username, password, timeout=30)
        print("✓ Connected.")
        
        # Rebuild and start backend
        cmd = "cd /opt/soobshio && docker compose up -d --build backend"
        print(f"Executing: {cmd}")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.channel.recv_exit_status()
        print(stdout.read().decode('utf-8'))
        
        print("Waiting 10 seconds for container startup...")
        time.sleep(10)
        
        # Check logs
        cmd_logs = "cd /opt/soobshio && docker compose logs --tail=50 backend"
        stdin, stdout, stderr = ssh.exec_command(cmd_logs)
        print("\n--- BACKEND DOCKER LOGS ---")
        print(stdout.read().decode('utf-8'))
        print(stderr.read().decode('utf-8'))
        
    except Exception as e:
        print(f"❌ Failed: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
