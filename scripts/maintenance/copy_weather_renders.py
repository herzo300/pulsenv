# scripts/maintenance/copy_weather_renders.py
import shutil
from pathlib import Path

def main():
    src_dir = Path("c:/Soobshio_project/public/models3d/renders")
    dst_dir = Path("c:/Soobshio_project/services/Frontend/assets/weather_3d")
    
    sun_src = src_dir / "sun_render_ultra.png"
    moon_src = src_dir / "moon_render_ultra.png"
    
    if sun_src.exists():
        shutil.copy(str(sun_src), str(dst_dir / "sun.png"))
        print("Copied sun_render_ultra.png -> weather_3d/sun.png")
    else:
        print("x sun_render_ultra.png not found")
        
    if moon_src.exists():
        shutil.copy(str(moon_src), str(dst_dir / "moon.png"))
        shutil.copy(str(moon_src), str(dst_dir / "moon_crescent.png"))
        print("Copied moon_render_ultra.png -> weather_3d/moon.png and moon_crescent.png")
    else:
        print("x moon_render_ultra.png not found")

if __name__ == "__main__":
    main()
