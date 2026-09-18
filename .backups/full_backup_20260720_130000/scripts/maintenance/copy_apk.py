# scripts/maintenance/copy_apk.py
import shutil
from pathlib import Path
import os

def main():
    desktop = Path(os.path.expanduser("~")) / "Desktop"
    
    # Possible paths for APK
    candidates = [
        Path("c:/Soobshio_project/services/Frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"),
        Path("c:/Soobshio_project/services/Frontend/build/app/outputs/flutter-apk/app-release.apk"),
        Path("c:/Soobshio_project/services/Frontend/build/app/outputs/apk/release/app-release.apk"),
        Path("c:/Soobshio_project/services/Frontend/build/app/outputs/apk/release/app-release-unsigned.apk")
    ]
    
    copied = False
    for cand in candidates:
        if cand.exists():
            dst = desktop / "city_pulse_arm64.apk"
            shutil.copy(str(cand), str(dst))
            print(f"Copied APK: {cand} -> {dst}")
            copied = True
            break
            
    if not copied:
        print("x APK file not found in build outputs")

if __name__ == "__main__":
    main()
