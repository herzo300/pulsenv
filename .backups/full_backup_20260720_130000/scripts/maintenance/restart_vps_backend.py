# scripts/maintenance/restart_vps_backend.py
import paramiko

def main():
    print("=== CONNECTING TO VPS TO REBUILD BACKEND CONTAINER ===")
    host = "45.153.68.59"
    username = "root"
    password = "sf?UQ8AYk*-DB8"
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(host, 22, username, password, timeout=30)
        print("✓ Connected.")
        
        # Pull backend down, rebuild and start up
        commands = [
            "cd /opt/soobshio && docker compose stop backend",
            "cd /opt/soobshio && docker compose rm -f backend",
            "cd /opt/soobshio && docker compose up -d --build backend"
        ]
        
        for cmd in commands:
            print(f"Executing: {cmd}")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            stdout.channel.recv_exit_status()
            print(stdout.read().decode('utf-8'))
            
        print("✓ Backend container rebuild triggered successfully.")
        
    except Exception as e:
        print(f"❌ Failed: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
