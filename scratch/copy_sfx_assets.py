import os
import shutil

src_dir = r"C:\Soobshio_project\public\audio"
dst_dir = r"C:\Soobshio_project\services\Frontend\assets\audio"

files = [
    "ui_click_soft.mp3",
    "ui_confirm_soft.mp3",
    "ui_notification_soft.mp3",
    "ui_toggle_soft.mp3",
    "ui_alert_soft.mp3",
]

for f in files:
    src = os.path.join(src_dir, f)
    dst = os.path.join(dst_dir, f)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"Copied {f} to {dst}")
