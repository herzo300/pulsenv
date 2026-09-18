# scripts/maintenance/find_and_deploy.py
import os
import sys
import shutil
import subprocess
from pathlib import Path

# Force UTF-8 on stdout
if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path("C:/Soobshio_project")
candidates = [
    ROOT / "services" / "Frontend" / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk",
    ROOT / "services" / "Frontend" / "build" / "app" / "outputs" / "flutter-apk" / "app-arm64-v8a-release.apk",
    ROOT / "CityPulse-arm64-lite.apk"
]

src = None
for c in candidates:
    if c.exists() and c.is_file() and c.stat().st_size > 10 * 1024 * 1024:
        src = c
        print(f"FOUND SOURCE: {src} ({src.stat().st_size / (1024*1024):.2f} MB)")
        break

if not src:
    all_apks = list((ROOT / "services" / "Frontend" / "build").glob("**/*.apk"))
    for a in all_apks:
        if a.stat().st_size > 10 * 1024 * 1024:
            src = a
            print(f"FOUND IN GLOB: {src} ({src.stat().st_size / (1024*1024):.2f} MB)")
            break

if not src:
    print("FATAL: No APK found on system > 10MB")
    sys.exit(1)

# Destinations
user_profile = Path(os.environ.get("USERPROFILE", "C:/Users/рс"))

destinations = [
    user_profile / "Desktop",
    user_profile / "Downloads",
    user_profile / "OneDrive" / "Desktop",
    Path("C:/Users/Public/Desktop"),
    Path("C:/Users/Public/Downloads"),
    ROOT
]

success_paths = []
for d in destinations:
    try:
        if d.is_dir():
            target = d / "CityPulse-arm64-lite.apk"
            shutil.copy2(src, target)
            size_mb = target.stat().st_size / (1024 * 1024)
            print(f"COPIED TO: {target} ({size_mb:.2f} MB)")
            success_paths.append(target)
    except Exception as ex:
        print(f"Notice: skipped {d}: {ex}")

print(f"\nTotal files successfully written: {len(success_paths)}")

# Open explorer showing the Desktop file
main_desktop_file = user_profile / "Desktop" / "CityPulse-arm64-lite.apk"
if main_desktop_file.exists():
    try:
        subprocess.Popen(f'explorer.exe /select,"{main_desktop_file}"', shell=True)
        print("Opened Explorer window highlighting the APK file on Desktop.")
    except Exception as e:
        print(f"Could not open explorer: {e}")
