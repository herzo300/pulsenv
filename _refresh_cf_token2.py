"""Try refreshing CF token via different endpoint"""
import urllib.request, json, os, urllib.parse

toml_path = os.path.join(os.environ['APPDATA'], 'xdg.config', '.wrangler', 'config', 'default.toml')
with open(toml_path, 'r') as f:
    content = f.read()

refresh_token = None
for line in content.split('\n'):
    if line.strip().startswith('refresh_token'):
        refresh_token = line.split('"')[1]
        break

# Try via api.cloudflare.com instead
endpoints = [
    'https://api.cloudflare.com/client/v4/user/tokens/verify',
]

# First check if current token still works via API
oauth_token = None
for line in content.split('\n'):
    if line.strip().startswith('oauth_token'):
        oauth_token = line.split('"')[1]
        break

print(f"Current token: {oauth_token[:20]}...")

req = urllib.request.Request('https://api.cloudflare.com/client/v4/user/tokens/verify',
    headers={'Authorization': f'Bearer {oauth_token}'})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
    print(f"Token verify: {result.get('success')} - {result.get('result', {}).get('status')}")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"Token verify failed: {e.code} - {body[:200]}")
except Exception as e:
    print(f"Token verify error: {e}")

# Try to use wrangler to refresh
print("\nTrying wrangler token refresh...")
import subprocess
r = subprocess.run(['npx', 'wrangler', 'whoami'], capture_output=True, text=True, timeout=30,
    env={**os.environ, 'CLOUDFLARE_API_TOKEN': oauth_token})
print(f"wrangler whoami: {r.returncode}")
if r.stdout: print(r.stdout[:200])
if r.stderr: print(r.stderr[:200])
