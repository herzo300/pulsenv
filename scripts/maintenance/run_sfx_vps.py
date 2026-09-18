# scripts/maintenance/run_sfx_vps.py
import os
import sys
import paramiko

# Add project root to path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(PROJECT_ROOT)

def main():
    print("=== CONNECTING TO VPS VIA SSH TO GENERATE AI SFX ===")
    
    # Connection parameters
    host = "45.153.68.59"
    port = 22
    username = "root"
    password = "sf?UQ8AYk*-DB8"
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(host, port, username, password, timeout=30)
        print("✓ Connected to Timeweb VPS.")
        
        # Command to run SFX generation script inside the running backend container
        cmd = "docker compose exec -T backend python /app/scripts/maintenance/generate_sfx_on_vps.py"
        print(f"Running command on remote server:\n  $ {cmd}")
        
        stdin, stdout, stderr = ssh.exec_command(f"cd /opt/soobshio && {cmd}")
        exit_status = stdout.channel.recv_exit_status()
        
        out = stdout.read().decode('utf-8')
        err = stderr.read().decode('utf-8')
        
        print("\n--- STDOUT ---")
        print(out)
        if err:
            print("--- STDERR ---")
            print(err)
            
        print(f"Exit status: {exit_status}")
        
        if exit_status == 0:
            # Copy files from container to host first so SFTP can access them
            copy_cmd = "mkdir -p /opt/soobshio/static/sounds && docker cp soobshio_backend:/app/static/sounds/. /opt/soobshio/static/sounds/"
            print(f"Extracting sounds from container to host:\n  $ {copy_cmd}")
            stdin, stdout, stderr = ssh.exec_command(copy_cmd)
            stdout.channel.recv_exit_status()

            print("\nDownloading generated files back to local asset folders...")
            sftp = ssh.open_sftp()
            
            # Local sound directories
            local_sounds_dir = os.path.join(PROJECT_ROOT, "public", "sounds")
            local_assets_dir = os.path.join(PROJECT_ROOT, "services", "Frontend", "assets", "audio")
            
            os.makedirs(local_sounds_dir, exist_ok=True)
            os.makedirs(local_assets_dir, exist_ok=True)
            
            filenames = ["menu_confirm.mp3", "menu_notification.mp3", "splash_gravity.mp3", "vip_upgrade.mp3"]
            
            for fname in filenames:
                remote_file = f"/opt/soobshio/static/sounds/{fname}"
                
                # Copy to public/sounds/
                local_public_path = os.path.join(local_sounds_dir, fname)
                sftp.get(remote_file, local_public_path)
                print(f"  [DOWNLOADED] {fname} -> public/sounds/")
                
                # Copy to Flutter assets audio/
                local_asset_path = os.path.join(local_assets_dir, fname)
                sftp.get(remote_file, local_asset_path)
                print(f"  [DOWNLOADED] {fname} -> Frontend assets/audio/")
                
            sftp.close()
            print("\n✓ SFX synchronization complete.")
        else:
            print("❌ Sound generation script failed on VPS.")
            
    except Exception as e:
        print(f"❌ SSH connection failed: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
