"""Verify worker.js MAP_HTML is valid"""
with open('cloudflare-worker/worker.js', 'r', encoding='utf-8') as f:
    c = f.read()

# Find MAP_HTML
idx = c.find('const MAP_HTML = `')
if idx < 0:
    print("MAP_HTML not found!")
    exit(1)

start = idx + len('const MAP_HTML = `')
# Find closing backtick (not escaped)
i = start
while i < len(c):
    if c[i] == '`' and (i == 0 or c[i-1] != '\\'):
        break
    i += 1

inner = c[start:i]
print(f"MAP_HTML: {len(inner)} chars")

# Check for unescaped backticks inside
import re
unesc_bt = [m.start() for m in re.finditer(r'(?<!\\)`', inner)]
print(f"Unescaped backticks inside: {len(unesc_bt)}")
if unesc_bt:
    for pos in unesc_bt[:5]:
        ctx = inner[max(0,pos-20):pos+20]
        print(f"  At {pos}: {repr(ctx)}")

# Check for unescaped ${
unesc_dl = [m.start() for m in re.finditer(r'(?<!\\)\$\{', inner)]
print(f"Unescaped dollar-brace: {len(unesc_dl)}")
