"""Generate compact fallback from infographic_data.json"""
import json, re

with open('infographic_data.json', 'r', encoding='utf-8') as f:
    d = json.load(f)

# Compact: trim large lists
fb = dict(d)
if 'transport' in fb and 'routes_list' in fb['transport']:
    fb['transport']['routes_list'] = fb['transport']['routes_list'][:10]
if 'agreements' in fb and 'top' in fb['agreements']:
    fb['agreements']['top'] = fb['agreements']['top'][:10]
if 'culture_clubs' in fb and 'items' in fb['culture_clubs']:
    fb['culture_clubs']['items'] = fb['culture_clubs']['items'][:8]
if 'accessibility' in fb and 'groups' in fb['accessibility']:
    fb['accessibility']['groups'] = fb['accessibility']['groups'][:8]
if 'road_works' in fb and 'items' in fb['road_works']:
    fb['road_works']['items'] = fb['road_works']['items'][:5]
if 'gmu_phones' in fb:
    fb['gmu_phones'] = fb['gmu_phones'][:8]
if 'azs' in fb:
    fb['azs'] = fb['azs'][:5]
for k in ['budget_bulletins', 'budget_info']:
    if k in fb and 'items' in fb[k]:
        fb[k]['items'] = fb[k]['items'][:5]
if 'hearings' in fb and 'recent' in fb['hearings']:
    fb['hearings']['recent'] = fb['hearings']['recent'][:3]
if 'msp' in fb and 'items' in fb['msp']:
    fb['msp']['items'] = fb['msp']['items'][:5]
if 'programs' in fb and 'items' in fb['programs']:
    fb['programs']['items'] = fb['programs']['items'][:3]

out = json.dumps(fb, ensure_ascii=False, separators=(',', ':'))
# Clean control characters
out = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', ' ', out)
# Replace \r\n with space
out = out.replace('\\r\\n', ' ').replace('\\r', ' ').replace('\\n', ' ')
# Balance parens in string values (not critical but avoids Node parse confusion)
with open('fallback_compact.json', 'w', encoding='utf-8') as f:
    f.write(out)
print(f'Fallback: {len(out)} chars')
# Verify
try:
    json.loads(out)
    print('JSON valid: OK')
except Exception as e:
    print(f'JSON error: {e}')
# Check paren balance
print(f'Parens: ( = {out.count("(")}, ) = {out.count(")")}')
