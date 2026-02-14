"""Check JS syntax by finding unmatched braces/parens"""
import re, json

with open('cloudflare-worker/info_script.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Check for common issues
# 1. Find the FALLBACK line and check it's valid JSON
m = re.search(r'const FALLBACK=(\{.*?\});', content)
if m:
    try:
        json.loads(m.group(1))
        print("FALLBACK JSON: OK")
    except json.JSONDecodeError as e:
        print(f"FALLBACK JSON ERROR: {e}")
        # Find position
        pos = e.pos
        snippet = m.group(1)[max(0,pos-50):pos+50]
        print(f"Near: ...{snippet}...")
else:
    print("FALLBACK not found!")

# 2. Check brace balance
opens = 0
for i, ch in enumerate(content):
    if ch == '{': opens += 1
    elif ch == '}': opens -= 1
    if opens < 0:
        line = content[:i].count('\n') + 1
        print(f"Extra closing brace at line {line}")
        break
if opens > 0:
    print(f"Missing {opens} closing braces")
elif opens == 0:
    print("Braces balanced: OK")

# 3. Check paren balance
opens = 0
for i, ch in enumerate(content):
    if ch == '(': opens += 1
    elif ch == ')': opens -= 1
    if opens < 0:
        line = content[:i].count('\n') + 1
        print(f"Extra closing paren at line {line}")
        break
if opens > 0:
    print(f"Missing {opens} closing parens")
elif opens == 0:
    print("Parens balanced: OK")

print(f"Total lines: {content.count(chr(10))+1}")
