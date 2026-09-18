# scripts/upload_apk.py
import os
import shutil
import requests
from pathlib import Path

def main():
    print("=== COPYING AND UPLOADING LATEST APK ===")
    
    # 1. Paths
    apk_source = Path(r"c:\Soobshio_project\services\Frontend\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk")
    desktop_dir = Path(r"C:\Users\рс\Desktop")
    apk_dest = desktop_dir / "citypulse_arm64_latest.apk"
    
    # Check if apk built successfully
    if not apk_source.exists():
        # Fallback check
        apk_source_alt = Path(r"c:\Soobshio_project\services\Frontend\build\app\outputs\apk\release\app-release.apk")
        if apk_source_alt.exists():
            apk_source = apk_source_alt
        else:
            print("Error: Compiled APK not found in build outputs. Please wait for the build task to finish.")
            return
            
    # 2. Copy to desktop
    try:
        shutil.copy2(apk_source, apk_dest)
        print(f"Successfully copied APK to desktop: {apk_dest}")
    except Exception as e:
        print(f"Failed to copy APK to desktop: {e}")
        return

    # 3. Upload to GoFile for instant sharing (Google Drive alternative)
    print("\nUploading to GoFile for quick download link...")
    try:
        # Get best server
        server_res = requests.get("https://api.gofile.io/getServer", timeout=10).json()
        if server_res.get("status") == "ok":
            server = server_res["data"]["server"]
            upload_url = f"https://{server}.gofile.io/uploadFile"
            
            with open(apk_dest, 'rb') as f:
                res = requests.post(upload_url, files={'file': f}, timeout=60).json()
                
            if res.get("status") == "ok":
                download_page = res["data"]["downloadPage"]
                print(f"Success! Your APK is available for download at: {download_page}")
            else:
                print(f"GoFile upload failed: {res}")
        else:
            print("Failed to contact GoFile servers.")
    except Exception as e:
        print(f"Network upload failed: {e}. You can still install the APK directly from your Desktop.")
        
    print("\n=== COMPLETED ===")

if __name__ == "__main__":
    main()
