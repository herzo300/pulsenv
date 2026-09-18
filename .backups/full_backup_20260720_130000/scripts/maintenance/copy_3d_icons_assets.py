# scripts/maintenance/copy_3d_icons_assets.py
import shutil
from pathlib import Path
import os

def main():
    src_dir = Path("c:/Soobshio_project/public/models3d/renders")
    dst_dir = Path("c:/Soobshio_project/services/Frontend/assets/3d_icons")
    dst_dir.mkdir(parents=True, exist_ok=True)
    
    categories = [
        "roads", "garbage", "snow", "utility", "animals", 
        "lost_pet", "items", "light", "traffic_parking", 
        "fire_flood", "noise", "ecology", "transport", "events"
    ]
    
    for cat in categories:
        src_file = src_dir / f"{cat}_render_ultra.png"
        if src_file.exists():
            shutil.copy(str(src_file), str(dst_dir / f"{cat}_3d.png"))
            print(f"Copied 3D asset: {src_file.name} -> {cat}_3d.png")
        else:
            print(f"x Source 3D asset not found: {src_file.name}")

if __name__ == "__main__":
    main()
