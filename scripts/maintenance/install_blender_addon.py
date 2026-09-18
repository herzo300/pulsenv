# scripts/maintenance/install_blender_addon.py
import re
from pathlib import Path

def main():
    src_path = Path(r"C:\Users\рс\.gemini\antigravity\brain\5208f340-ab5e-4a83-86c9-2eceabeae199\.system_generated\steps\8150\content.md")
    if not src_path.exists():
        print(f"Error: Source file {src_path} not found.")
        return
        
    with open(src_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    # Find start of python code (skip markdown headers)
    parts = content.split("---", 1)
    if len(parts) < 2:
        print("Error: Could not find separator '---' in source file.")
        return
        
    python_code = parts[1].strip()
    
    # Save destinations
    dest_dir = Path(r"C:\Users\рс\AppData\Roaming\Blender Foundation\Blender\5.1\scripts\addons")
    dest_dir.mkdir(parents=True, exist_ok=True)
    
    files = ["blender_mcp_addon.py", "addon.py"]
    for fname in files:
        dest_file = dest_dir / fname
        with open(dest_file, "w", encoding="utf-8") as f:
            f.write(python_code)
        print(f"Successfully wrote addon to: {dest_file}")

if __name__ == "__main__":
    main()
