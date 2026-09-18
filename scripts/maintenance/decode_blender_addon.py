# scripts/maintenance/decode_blender_addon.py
import json
import base64
from pathlib import Path

def main():
    json_file = Path(r"C:\Users\рс\.gemini\antigravity\brain\5208f340-ab5e-4a83-86c9-2eceabeae199\.system_generated\steps\8229\content.md")
    if not json_file.exists():
        print("Error: content.md not found.")
        return
        
    with open(json_file, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    # Find the JSON line (usually starting at line 5, index 4)
    json_data_str = ""
    for line in lines:
        if line.strip().startswith("{") and '"content"' in line:
            json_data_str = line.strip()
            break
            
    if not json_data_str:
        print("Error: Could not find JSON content in content.md.")
        return
        
    try:
        data = json.loads(json_data_str)
        b64_content = data["content"].replace("\n", "").replace("\r", "")
        decoded_bytes = base64.b64decode(b64_content)
        python_code = decoded_bytes.decode("utf-8")
        
        print(f"Decoded {len(python_code)} characters of Python code.")
        
        # Save destinations
        dest_dir = Path(r"C:\Users\рс\AppData\Roaming\Blender Foundation\Blender\5.1\scripts\addons")
        dest_dir.mkdir(parents=True, exist_ok=True)
        
        files = ["blender_mcp_addon.py", "addon.py"]
        for fname in files:
            dest_file = dest_dir / fname
            with open(dest_file, "w", encoding="utf-8") as f:
                f.write(python_code)
            print(f"Successfully wrote decoded addon to: {dest_file}")
            
    except Exception as e:
        print(f"Error parsing/decoding JSON: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
