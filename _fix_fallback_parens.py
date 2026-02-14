"""Find and fix unmatched parens in fallback JSON"""
import json

with open('fallback_compact.json', 'r', encoding='utf-8') as f:
    fb = f.read()

# Find position of unmatched (
depth = 0
positions = []
for i, ch in enumerate(fb):
    if ch == '(':
        depth += 1
        positions.append(i)
    elif ch == ')':
        depth -= 1
        if positions:
            positions.pop()

# positions now contains unmatched ( positions
for pos in positions:
    snippet = fb[max(0,pos-30):pos+30]
    print(f"Unmatched ( at pos {pos}: ...{snippet}...")

# Fix: escape parens in the JSON string values or balance them
# Actually, the issue is that the FALLBACK is inside JS, and Node's parser
# doesn't care about parens in strings. The real issue is the _update_fallback.py
# regex might be wrong. Let me check the actual FALLBACK line in info_script.js

with open('cloudflare-worker/info_script.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Find FALLBACK
start = content.find('const FALLBACK=')
# Find the end - it should be };
# But the regex in _update_fallback.py uses non-greedy match which might cut off
end = content.find(';\n', start)
fallback_str = content[start:end+1]
print(f"\nFALLBACK length: {len(fallback_str)}")
print(f"Starts with: {fallback_str[:80]}")
print(f"Ends with: ...{fallback_str[-80:]}")

# Check if it's valid JSON (after removing 'const FALLBACK=')
json_str = fallback_str.replace('const FALLBACK=', '').rstrip(';')
try:
    json.loads(json_str)
    print("FALLBACK JSON is valid!")
except json.JSONDecodeError as e:
    print(f"FALLBACK JSON error: {e}")
