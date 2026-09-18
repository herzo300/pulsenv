import os
import urllib.request
import urllib.parse
from PIL import Image, ImageDraw, ImageFilter

target_dir = r"C:\Soobshio_project\services\Frontend\assets\images\onboarding"
os.makedirs(target_dir, exist_ok=True)

prompts = {
    "slide_1_ai_dispatcher.png": "Futuristic 3D AI City Control Center for Nizhnevartovsk, glowing digital holographic city map, neon cyan and gold liquid drop core, 8k resolution octane render",
    "slide_2_p2p_mesh.png": "3D Cyberpunk Mesh Network nodes connecting snow-covered city buildings at -40C, glowing blue mesh lines, high tech winter city, 8k resolution",
    "slide_3_gost_claims.png": "3D Luxury digital document with electronic gold wax seal and cyan holographic verification lines, 8k resolution render",
    "slide_4_ob_weather.png": "3D Majestic Ob river embankment with northern lights aurora borealis and glowing digital hydrology water level sensor, 8k resolution",
    "slide_5_community.png": "3D Friendly neighborhood community isometric houses with glowing radar lost and found pets pins, 8k resolution"
}

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

for filename, prompt in prompts.items():
    filepath = os.path.join(target_dir, filename)
    url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(prompt)}?width=1080&height=1920&seed=42&nologo=true"
    print(f"Generating {filename}...")
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=12) as resp, open(filepath, 'wb') as out:
            out.write(resp.read())
        print(f"Successfully generated: {filepath}")
    except Exception as err:
        print(f"Fallback rendering locally for {filename}: {err}")
        img = Image.new("RGB", (1080, 1920), (15, 23, 42))
        draw = ImageDraw.Draw(img)
        # Draw gradient background
        for y in range(1920):
            r = int(15 + (y / 1920) * 30)
            g = int(23 + (y / 1920) * 40)
            b = int(42 + (y / 1920) * 80)
            draw.line([(0, y), (1080, y)], fill=(r, g, b))
        # Draw glowing central ring
        for radius in range(400, 200, -10):
            alpha = int(180 * (1 - radius / 400))
            draw.ellipse([540 - radius, 960 - radius, 540 + radius, 960 + radius], outline=(0, 229, 255), width=2)
        img.save(filepath, format="PNG")
        print(f"Saved local fallback: {filepath}")

print("ALL ONBOARDING SLIDE PHOTOS GENERATED SUCCESSFULLY!")
