"""Check worker.js for template literal issues"""
with open('cloudflare-worker/worker.js', 'r', encoding='utf-8') as f:
    c = f.read()
print(f'Size: {len(c)} chars')

# Find MAP_HTML section
idx = c.find('const MAP_HTML')
if idx > 0:
    # Find the closing backtick-semicolon
    start = c.find('`', idx)
    depth = 0
    end = -1
    for i in range(start + 1, len(c)):
        if c[i] == '`' and c[i-1:i+1] != '\\`':
            end = i
            break
    if end > 0:
        inner = c[start+1:end]
        print(f'MAP_HTML length: {len(inner)}')
        # Check for unescaped backticks
        bt = inner.count('`')
        print(f'Unescaped backticks: {bt}')
        # Check for unescaped ${}
        import re
        unesc = re.findall(r'(?<!\\)\$\{', inner)
        print(f'Unescaped dollar-brace: {len(unesc)}')
        if unesc:
            for m in re.finditer(r'(?<!\\)\$\{', inner):
                pos = m.start()
                context = inner[max(0,pos-30):pos+30]
                print(f'  At pos {pos}: ...{repr(context)}...')
    else:
        print('Could not find end of MAP_HTML')

# Check for roundRect (not supported in all environments)
if 'roundRect' in c:
    print('WARNING: roundRect used - may not be supported in older browsers')
