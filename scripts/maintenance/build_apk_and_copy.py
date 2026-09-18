import subprocess
import shutil
import os
import sys

frontend_dir = os.path.abspath('services/Frontend')
desktop_target = r'C:\Users\рс\Desktop\CityPulse-arm64-lite.apk'

print('Building Flutter APK...')
cmd = ['flutter.bat', 'build', 'apk', '--target-platform', 'android-arm64', '--release', '--no-tree-shake-icons']
res = subprocess.run(cmd, cwd=frontend_dir, capture_output=True, text=True)

print('Build stdout:', res.stdout[-1000:])
print('Build stderr:', res.stderr[-1000:])

apk_path = os.path.join(frontend_dir, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk')
if os.path.exists(apk_path):
    shutil.copyfile(apk_path, desktop_target)
    print(f'SUCCESS! Copied {apk_path} ({os.path.getsize(apk_path)} bytes) to {desktop_target}')
else:
    print('ERROR: APK file not found!')
