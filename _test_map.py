"""Test map endpoint via CF API"""
import os, json, urllib.request

toml_path = os.path.join(os.environ['APPDATA'], 'xdg.config', '.wrangler', 'config', 'default.toml')
with open(toml_path, 'r') as f:
    content = f.read()
cf_token = None
for line in content.split('\n'):
    if line.strip().startswith('oauth_token'):
        cf_token = line.split('"')[1]
        break

# Check worker is deployed via CF API
headers = {'Authorization': f'Bearer {cf_token}'}
req = urllib.request.Request(
    'https://api.cloudflare.com/client/v4/accounts/b55123fb7c25f3c5f38a1dcab5a36fa8/workers/scripts/anthropic-proxy',
    headers=headers
)
try:
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
        print(f"Worker exists! Size: {len(data)} bytes")
        # Check if MAP_HTML is in the worker
        text = data.decode('utf-8', errors='replace')
        if 'MAP_HTML' in text:
            print("✅ MAP_HTML found in worker")
        if 'INFO_HTML' in text:
            print("✅ INFO_HTML found in worker")
        if 'Пульс города' in text:
            print("✅ 'Пульс города' found in worker")
        if 'filterPanel' in text:
            print("✅ filterPanel found (new map design)")
        if 'dayFilters' in text:
            print("✅ dayFilters found (day filter feature)")
        if 'timeline' in text:
            print("✅ timeline found (bottom chart)")
except Exception as e:
    print(f"Error: {e}")
