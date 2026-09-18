import os
import zipfile
import shutil

source_dir = r"c:\Soobshio_project"
output_zip = r"c:\Users\рс\Desktop\citypulse_timeweb_migration.zip"

skip_folders = [
    "Frontend", "Web", "__pycache__", ".git", "deploy_package", "tmp", ".venv", ".cursor", "public"
]

print("Collecting files for full Timeweb Docker Migration...")

try:
    with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # 1. Add docker resources to root
        deploy_dir = os.path.join(source_dir, "services", "deploy_package")
        if os.path.exists(deploy_dir):
            for filename in os.listdir(deploy_dir):
                filepath = os.path.join(deploy_dir, filename)
                if os.path.isfile(filepath):
                    zipf.write(filepath, arcname=filename)
        
        # 2. Add full backend ecosystem
        for root, dirs, files in os.walk(source_dir):
            # Exclude unwanted directories entirely (including deeply nested ones if needed)
            dirs[:] = [d for d in dirs if d not in skip_folders]
            
            for file in files:
                if file.endswith('.zip') or 'realesrgan' in file.lower() or 'monitoring_session.session' in file:
                    continue
                
                filepath = os.path.join(root, file)
                # Ensure we only include backend services (python) and config
                if "Frontend\\" in filepath or "Web\\" in filepath or "tmp\\" in filepath or ".venv\\" in filepath:
                    continue
                
                # Make path relative for the zip
                rel_path = os.path.relpath(filepath, source_dir)
                zipf.write(filepath, arcname=rel_path)

    print(f"Migration package successfully compressed to: {output_zip}")
    print("WARNING: realesrgan_service (Face Upscale) was completely excluded to save VRAM and disk space.")
    
except Exception as e:
    print(f"Error building migration package: {e}")
