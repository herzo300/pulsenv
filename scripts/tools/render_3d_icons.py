import os
from PIL import Image, ImageDraw, ImageFilter

# Create high-resolution 3D glassmorphic liquid oil drop + neon cyan pulse emblem
width, height = 1024, 1024
image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)

# Background glowing radial vignette
bg = Image.new("RGBA", (width, height), (15, 23, 42, 255))
bg_draw = ImageDraw.Draw(bg)

# Draw neon cyan pulse circle
for r in range(400, 200, -10):
    alpha = int(120 * (1 - r / 400))
    bg_draw.ellipse([512 - r, 512 - r, 512 + r, 512 + r], outline=(0, 229, 255, alpha), width=3)

# Draw golden oil drop body
drop_points = []
for angle in range(0, 360, 2):
    import math
    rad = math.radians(angle)
    # Tear drop formula
    r_val = 300 * (1 - math.sin(rad)) / 2 + 120
    x = 512 + r_val * math.cos(rad) * 0.85
    y = 550 - r_val * math.sin(rad) * 1.1
    drop_points.append((x, y))

# Golden Liquid Gradient Fill
for i in range(1, 20):
    scale = 1 - i * 0.03
    scaled_pts = [(512 + (p[0] - 512) * scale, 550 + (p[1] - 550) * scale) for p in drop_points]
    col = (20, 20, 25, 240) if i > 5 else (212, 175, 55, 255)
    bg_draw.polygon(scaled_pts, fill=(15 + i*10, 23 + i*8, 42 + i*5, 255))

# Golden rim glow
bg_draw.polygon(drop_points, outline=(255, 215, 0, 240), width=12)

# Neon Cyan Heartbeat Pulse Line inside droplet
pulse_pts = [
    (260, 550), (360, 550), (410, 420), (460, 680), (512, 360), (560, 620), (610, 480), (660, 550), (760, 550)
]
bg_draw.line(pulse_pts, fill=(0, 229, 255, 255), width=16, joint="round")

# Glass specular highlight curve
bg_draw.arc([320, 320, 480, 580], start=180, end=270, fill=(255, 255, 255, 200), width=14)

# Save high-res logo
assets_dir = r"C:\Soobshio_project\services\Frontend\assets\images"
os.makedirs(assets_dir, exist_ok=True)
logo_path = os.path.join(assets_dir, "city_pulse_logo.png")
bg.save(logo_path)
print(f"Generated 3D Logo: {logo_path}")

# Create rounded Android Launcher Icon
icon_size = (1024, 1024)
icon_img = Image.new("RGBA", icon_size, (0, 0, 0, 0))
mask = Image.new("L", icon_size, 0)
mask_draw = ImageDraw.Draw(mask)
# Squircle rounded corner radius 220
mask_draw.rounded_rectangle([40, 40, 984, 984], radius=220, fill=255)

icon_img.paste(bg, (0, 0), mask)

# Save to all mipmap densities
mipmap_base = r"C:\Soobshio_project\services\Frontend\android\app\src\main\res"
densities = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

for folder, size in densities.items():
    dest_dir = os.path.join(mipmap_base, folder)
    os.makedirs(dest_dir, exist_ok=True)
    resized = icon_img.resize(size, Image.Resampling.LANCZOS)
    resized.save(os.path.join(dest_dir, "ic_launcher.png"))
    resized.save(os.path.join(dest_dir, "launcher_icon.png"))
    resized.save(os.path.join(dest_dir, "ic_launcher_round.png"))
    print(f"Updated {folder} launcher icon")

print("ALL 3D LAUNCHER ICONS RENDERED & PLACED SUCCESSFULLY!")
