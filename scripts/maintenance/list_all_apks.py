# scripts/maintenance/list_all_apks.py
import sys
from pathlib import Path

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path("C:/Soobshio_project")
build_dir = ROOT / "services" / "Frontend" / "build"

print("--- ALL APKS IN BUILD ---")
for p in build_dir.glob("**/*.apk"):
    print(f"  {p} ({p.stat().st_size / (1024*1024):.2f} MB)")

desktop_apk = Path("C:/Users/рс/Desktop/CityPulse-arm64-lite.apk")
print(f"\nDesktop APK exists: {desktop_apk.exists()} ({desktop_apk.stat().st_size / (1024*1024):.2f} MB)")
