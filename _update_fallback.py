"""Replace FALLBACK in info_script.js"""

with open('cloudflare-worker/info_script.js', 'r', encoding='utf-8') as f:
    content = f.read()

with open('fallback_compact.json', 'r', encoding='utf-8') as f:
    fb = f.read()

# Find and replace FALLBACK — use exact markers instead of regex
marker_start = 'const FALLBACK='
marker_end = ';\n'
start = content.find(marker_start)
if start == -1:
    print("ERROR: FALLBACK not found!")
    exit(1)

# Find the end of the JSON object — count braces
pos = start + len(marker_start)
depth = 0
in_string = False
escape = False
end = -1
for i in range(pos, len(content)):
    ch = content[i]
    if escape:
        escape = False
        continue
    if ch == '\\':
        escape = True
        continue
    if ch == '"':
        in_string = not in_string
        continue
    if in_string:
        continue
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break

if end == -1:
    print("ERROR: Could not find end of FALLBACK!")
    exit(1)

# Replace
old_fallback = content[start:end]
new_content = content[:start] + 'const FALLBACK=' + fb + content[end:]

with open('cloudflare-worker/info_script.js', 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f'Done. Size: {len(new_content)} chars')
print(f'Old FALLBACK: {len(old_fallback)} chars')
print(f'New FALLBACK: {len(fb)} chars')
print(f'Has agreements: {"agreements" in new_content}')
