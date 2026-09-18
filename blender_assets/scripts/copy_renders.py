import os
import shutil

SRC_DIR = r"C:\Soobshio_project\blender_assets\output"
DST_DIR = r"C:\Soobshio_project\services\Frontend\assets\3d_icons"

os.makedirs(DST_DIR, exist_ok=True)

# 1. Civic categories map: cat_<name>.png -> <name>_3d.png
civic_map = {
    "cat_animals.png": "animals_3d.png",
    "cat_chp.png": "chp_3d.png",
    "cat_construction.png": "construction_3d.png",
    "cat_dorogi.png": "dorogi_3d.png",
    "cat_ecology.png": "ecology_3d.png",
    "cat_education.png": "education_3d.png",
    "cat_event.png": "event_3d.png",
    "cat_gkh.png": "gkh_3d.png",
    "cat_items.png": "items_3d.png",
    "cat_lighting.png": "lighting_3d.png",
    "cat_medicine.png": "medicine_3d.png",
    "cat_other.png": "other_3d.png",
    "cat_parking.png": "parking_3d.png",
    "cat_security.png": "security_3d.png",
    "cat_snow.png": "snow_3d.png",
    "cat_transport.png": "transport_3d.png"
}

# 2. Lost & found categories: lf_<name>.png -> lost_<name>_3d.png
lost_found_map = {
    "lf_cat.png": "lost_cat_3d.png",
    "lf_dog.png": "lost_dog_3d.png",
    "lf_keys.png": "lost_keys_3d.png",
    "lf_phone.png": "lost_phone_3d.png",
    "lf_wallet.png": "lost_wallet_3d.png",
    "lf_backpack.png": "lost_backpack_3d.png",
    "lf_passport.png": "lost_passport_3d.png",
    "lf_event.png": "event_3d.png", # Megaphone for events / news
    "lf_garbage.png": "garbage_3d.png" # Garbage bin
}

# Copy Civic
for src, dst in civic_map.items():
    src_path = os.path.join(SRC_DIR, src)
    dst_path = os.path.join(DST_DIR, dst)
    if os.path.exists(src_path):
        shutil.copy2(src_path, dst_path)
        print(f"Copied & Renamed: {src} -> {dst}")

# Copy Lost & Found
for src, dst in lost_found_map.items():
    src_path = os.path.join(SRC_DIR, src)
    dst_path = os.path.join(DST_DIR, dst)
    if os.path.exists(src_path):
        shutil.copy2(src_path, dst_path)
        print(f"Copied & Renamed: {src} -> {dst}")
