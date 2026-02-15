"""Update FALLBACK in info_script.js with data from infographic_data.json"""
import json

with open("infographic_data.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Generate compact JSON
fallback = json.dumps(data, ensure_ascii=False, separators=(',', ':'))

# Read info_script.js
with open("cloudflare-worker/info_script.js", "r", encoding="utf-8") as f:
    content = f.read()

# Find and replace FALLBACK
marker_start = "const FALLBACK="
marker_end = ";\n\nasync function loadData()"
idx_start = content.find(marker_start)
idx_end = content.find(marker_end)

if idx_start == -1 or idx_end == -1:
    print(f"Markers not found: start={idx_start}, end={idx_end}")
    # Try alternative
    marker_end2 = ";\nasync function loadData()"
    idx_end = content.find(marker_end2)
    if idx_end == -1:
        print("Cannot find end marker either")
        exit(1)
    marker_end = marker_end2

new_content = content[:idx_start] + "const FALLBACK=" + fallback + content[idx_end:]

with open("cloudflare-worker/info_script.js", "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"Updated FALLBACK: {len(fallback)} chars")
print(f"File size: {len(new_content)} chars")
