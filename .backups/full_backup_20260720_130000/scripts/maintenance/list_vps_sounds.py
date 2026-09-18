# scripts/maintenance/list_vps_sounds.py
import paramiko

def main():
    print("=== LISTING SOUND FILES ON VPS ===")
    host = "45.153.68.59"
    username = "root"
    password = "sf?UQ8AYk*-DB8"
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(host, 22, username, password, timeout=30)
        print("✓ Connected.")
        
        cmd = "find /opt/soobshio/static -type f"
        stdin, stdout, stderr = ssh.exec_command(cmd)
        print(stdout.read().decode('utf-8'))
        print(stderr.read().decode('utf-8'))
        
    except Exception as e:
        print(f"❌ Failed: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
