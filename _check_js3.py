"""Check paren balance in FALLBACK JSON"""
with open('fallback_compact.json', 'r', encoding='utf-8') as f:
    fb = f.read()

opens = fb.count('(')
closes = fb.count(')')
print(f"FALLBACK parens: ( = {opens}, ) = {closes}, diff = {opens - closes}")

# Find unmatched
if opens != closes:
    depth = 0
    for i, ch in enumerate(fb):
        if ch == '(': depth += 1
        elif ch == ')': depth -= 1
    print(f"Final depth: {depth}")

# Check the rest of the file
with open('cloudflare-worker/info_script.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove FALLBACK line to check rest
import re
# Find FALLBACK assignment
start = content.find('const FALLBACK=')
end = content.find(';\n', start)
rest = content[:start] + content[end+2:]
depth = 0
for i, ch in enumerate(rest):
    if ch == '(': depth += 1
    elif ch == ')': depth -= 1
print(f"Rest of file paren balance: {depth}")
