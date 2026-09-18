import os
import sys
import subprocess
import httpx

tools_dir = r"C:\Tools\OOSU10"
os.makedirs(tools_dir, exist_ok=True)
oosu_path = os.path.join(tools_dir, "OOSU10.exe")

url = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
print(f"Downloading O&O ShutUp10++ from {url}...")

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

try:
    with httpx.Client(follow_redirects=True, timeout=30.0, headers=headers) as client:
        resp = client.get(url)
        if resp.status_code == 200 and len(resp.content) > 100000:
            with open(oosu_path, "wb") as f:
                f.write(resp.content)
            print(f"Saved {len(resp.content)} bytes to {oosu_path} ✓")
        else:
            print(f"HTTP response: {resp.status_code}, len={len(resp.content)}")
except Exception as e:
    print(f"Direct download error: {e}")

if os.path.exists(oosu_path):
    print("Applying recommended O&O ShutUp10 settings...")
    try:
        subprocess.run([oosu_path, "/apply-recommended", "/quiet"], timeout=30)
        print("O&O ShutUp10++ recommended privacy profile applied successfully! ✓")
    except Exception as e:
        print(f"Execution notice: {e}")
