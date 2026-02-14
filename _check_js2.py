"""Find unmatched paren in info_script.js"""
with open('cloudflare-worker/info_script.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Track paren depth per line
depth = 0
for i, line in enumerate(lines):
    for ch in line:
        if ch == '(': depth += 1
        elif ch == ')': depth -= 1
    if depth < 0:
        print(f"Line {i+1}: extra ')' — depth={depth}")
        print(f"  {line.rstrip()}")
        break

if depth > 0:
    # Find where the last unclosed paren is
    # Go backwards
    depth2 = 0
    for i in range(len(lines)-1, -1, -1):
        for ch in reversed(lines[i]):
            if ch == ')': depth2 += 1
            elif ch == '(': depth2 -= 1
        if depth2 < 0:
            print(f"Unclosed '(' at line {i+1}: {lines[i].rstrip()[:100]}")
            break
    print(f"Total paren imbalance: +{depth}")
