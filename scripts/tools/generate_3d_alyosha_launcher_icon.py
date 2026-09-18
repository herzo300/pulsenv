import os
import math
import urllib.request
import urllib.parse
from PIL import Image, ImageDraw, ImageFilter, ImageOps

res_dir = r"C:\Soobshio_project\services\Frontend\android\app\src\main\res"

# Generate high resolution 1024x1024 icon
def create_alyosha_icon():
    # Attempt AI generation via Pollinations
    prompt = "3D isometric app icon featuring majestic silhouette of Alyosha Monument Nizhnevartovsk and neon cyan glowing city pulse wave line, dark glassmorphic squircle background, 8k resolution octane render"
    url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(prompt)}?width=1024&height=1024&seed=777&nologo=true"
    headers = {'User-Agent': 'Mozilla/5.0'}
    
    img = None
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=12) as resp:
            img = Image.open(resp).convert("RGBA")
            print("AI 3D Alyosha icon generated successfully via Pollinations!")
    except Exception as err:
        print(f"Generating high precision programmatic 3D Alyosha icon: {err}")
        
    if img is None:
        # Programmatic high-res 3D icon rendering
        img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # 1. Rounded squircle background
        squircle_rect = [64, 64, 960, 960]
        r = 220
        # Draw background gradient
        bg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        bg_draw = ImageDraw.Draw(bg)
        bg_draw.rounded_rectangle(squircle_rect, radius=r, fill=(15, 23, 42, 255))
        
        # Inner glow / border
        bg_draw.rounded_rectangle(squircle_rect, radius=r, outline=(0, 229, 255, 200), width=12)
        
        # 2. Glowing pulse wave
        pulse_pts = [
            (120, 512), (320, 512), (400, 360), (460, 680), 
            (540, 240), (620, 600), (680, 512), (904, 512)
        ]
        bg_draw.line(pulse_pts, fill=(0, 229, 255, 255), width=28)
        
        # 3. Alyosha Monument Silhouette in Center
        # Torch flame top: (512, 220)
        # Raised arm right holding flame: (512, 220) -> (580, 340) -> (530, 420)
        # Helmet/head: (490, 350)
        # Broad shoulders & torso: (440, 420) to (560, 420), down to (420, 780), (600, 780)
        alyosha_poly = [
            (512, 180), (535, 230), (520, 260), (580, 320), 
            (560, 390), (530, 410), (550, 450), (610, 520),
            (580, 780), (440, 780), (420, 520), (470, 450),
            (490, 410), (470, 360), (490, 320), (505, 230)
        ]
        bg_draw.polygon(alyosha_poly, fill=(241, 245, 249, 240))
        
        # Add flame glow at top
        bg_draw.ellipse([490, 140, 534, 195], fill=(245, 158, 11, 255))
        bg_draw.ellipse([498, 152, 526, 185], fill=(255, 237, 74, 255))
        
        img = bg

    # Make round version
    round_mask = Image.new("L", (1024, 1024), 0)
    round_draw = ImageDraw.Draw(round_mask)
    round_draw.ellipse([32, 32, 992, 992], fill=255)
    
    round_img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    round_img.paste(img, (0, 0), mask=round_mask)
    
    # Save sizes to Android mipmap folders
    sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for folder, size in sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Resize square icon
        sq_resized = img.resize((size, size), Image.Resampling.LANCZOS)
        sq_resized.save(os.path.join(folder_path, "ic_launcher.png"))
        sq_resized.save(os.path.join(folder_path, "launcher_icon.png"))
        
        # Resize round icon
        rd_resized = round_img.resize((size, size), Image.Resampling.LANCZOS)
        rd_resized.save(os.path.join(folder_path, "ic_launcher_round.png"))
        print(f"Saved icons for {folder} ({size}x{size})")

    # Save 512x512 preview for assets
    assets_icon = r"C:\Soobshio_project\services\Frontend\assets\icon.png"
    img.resize((512, 512), Image.Resampling.LANCZOS).save(assets_icon)
    print("Saved preview to assets/icon.png")

create_alyosha_icon()
