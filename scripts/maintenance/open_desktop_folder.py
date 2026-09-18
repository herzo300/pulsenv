# scripts/maintenance/open_desktop_folder.py
import os
import subprocess
from pathlib import Path

target = Path("C:/Users/рс/Desktop/CityPulse-arm64-lite.apk")
print(f"File {target} exists: {target.exists()} (size: {target.stat().st_size if target.exists() else 0} bytes)")

# Open Windows Explorer with the file selected
cmd = f'explorer.exe /select,"{target}"'
print(f"Running: {cmd}")
subprocess.Popen(cmd, shell=True)
