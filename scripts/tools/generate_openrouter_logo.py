import urllib.request
import urllib.parse
import os
import sys
from PIL import Image

logo_prompt = "A breathtaking 3D emblem logo for City Pulse app, glossy black gold liquid oil drop fused with neon cyan pulse heartbeat wave, futuristic city skyline inside glass droplet, 8k resolution, luxury render"
icon_prompt = "A luxury 3D Android app icon tile for City Pulse app, rounded squircle, glossy black gold oil drop with neon cyan heartbeat pulse, metallic dark blue border, 8k resolution"

target_dir = r"C:\Soobshio_project\services\Frontend\assets\images"
os.makedirs(target_dir, exist_ok=True)

logo_path = os.path.join(target_dir, "city_pulse_logo.png")
icon_path = os.path.join(target_dir, "ic_launcher_3d.png")

logo_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(logo_prompt)}?width=1024&height=1024&seed=42&nologo=true"
icon_url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(icon_prompt)}?width=1024&height=1024&seed=108&nologo=true"

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

def download_file(url, target):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp, open(target, 'wb') as out:
        out.write(resp.read())

print("Downloading 3D Logo from AI Generator...")
download_file(logo_url, logo_path)
print(f"Saved Logo: {logo_path}")

print("Downloading 3D Android Icon from AI Generator...")
download_file(icon_url, icon_path)
print(f"Saved Icon: {icon_path}")

# Resize and place into all Android mipmap directories
mipmap_base = r"C:\Soobshio_project\services\Frontend\android\app\src\main\res"
densities = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

img = Image.open(icon_path)

for folder, size in densities.items():
    dest_dir = os.path.join(mipmap_base, folder)
    os.makedirs(dest_dir, exist_ok=True)
    resized = img.resize(size, Image.Resampling.LANCZOS)
    
    # Save as ic_launcher.png, launcher_icon.png, and ic_launcher_round.png
    resized.save(os.path.join(dest_dir, "ic_launcher.png"))
    resized.save(os.path.join(dest_dir, "launcher_icon.png"))
    resized.save(os.path.join(dest_dir, "ic_launcher_round.png"))
    print(f"Updated {folder} ({size[0]}x{size[1]})")

print("All AI generated 3D icons & logo successfully updated!")
