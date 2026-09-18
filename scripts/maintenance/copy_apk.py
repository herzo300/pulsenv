# scripts/maintenance/copy_apk.py
import os
import sys
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
frontend_dir = ROOT / "services" / "Frontend"

print("Searching for built release APK...")
candidates = [
    frontend_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk",
    frontend_dir / "build" / "app" / "outputs" / "flutter-apk" / "app-arm64-v8a-release.apk",
]
src = None
for c in candidates:
    if c.exists():
        src = c
        break

if not src:
    all_apks = list(frontend_dir.glob("build/**/*.apk"))
    if all_apks:
        src = all_apks[0]

if not src:
    print("ERROR: No APK found in build directory!")
    sys.exit(1)

src_size_mb = src.stat().st_size / (1024 * 1024)
print(f"Found source: {src} ({src_size_mb:.2f} MB)")

# Desktop candidates
userprofile = os.environ.get("USERPROFILE", str(Path.home()))
profile_path = Path(userprofile)

desktop_candidates = [
    profile_path / "Desktop",
    profile_path / "OneDrive" / "Desktop",
    profile_path / "OneDrive - Personal" / "Desktop",
    Path("C:/Users/Public/Desktop"),
    ROOT / "CityPulse-arm64-lite.apk"
]

copied_count = 0
for d in desktop_candidates:
    try:
        if d.is_dir() or d.parent.is_dir():
            if d.is_dir():
                target = d / "CityPulse-arm64-lite.apk"
            else:
                target = d
            shutil.copy2(src, target)
            size_mb = target.stat().st_size / (1024 * 1024)
            print(f"✅ Copied to: {target} ({size_mb:.2f} MB)")
            copied_count += 1
    except Exception as ex:
        print(f"Notice: skipped {d} ({ex})")

print(f"\n🎉 Total copies placed: {copied_count}")
