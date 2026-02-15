"""Check for backticks outside CSS block in map_script.js"""
with open('cloudflare-worker/map_script.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()

in_css = False
css_end = 0
for i, line in enumerate(lines, 1):
    s = line.strip()
    if "S.textContent=" in s and "`" in s:
        in_css = True
        continue
    if in_css:
        if s == "`;":
            in_css = False
            css_end = i
            continue
        continue
    if "`" in line and not s.startswith("//"):
        print(f"Line {i}: {s[:120]}")

print(f"\nCSS block ends at line {css_end}")
