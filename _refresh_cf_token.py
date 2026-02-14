"""Refresh Cloudflare OAuth token using refresh_token"""
import urllib.request, json, os

toml_path = os.path.join(os.environ['APPDATA'], 'xdg.config', '.wrangler', 'config', 'default.toml')
with open(toml_path, 'r') as f:
    content = f.read()

# Extract refresh_token
refresh_token = None
for line in content.split('\n'):
    if line.strip().startswith('refresh_token'):
        refresh_token = line.split('"')[1]
        break

if not refresh_token:
    print("ERROR: No refresh_token found")
    exit(1)

print(f"Refresh token: {refresh_token[:20]}...")

# Refresh via Cloudflare OAuth
data = urllib.parse.urlencode({
    'grant_type': 'refresh_token',
    'refresh_token': refresh_token,
    'client_id': '54d11594-84e4-41aa-b438-e81b8fa78ee7',
}).encode()

import urllib.parse
data = urllib.parse.urlencode({
    'grant_type': 'refresh_token',
    'refresh_token': refresh_token,
    'client_id': '54d11594-84e4-41aa-b438-e81b8fa78ee7',
}).encode()

req = urllib.request.Request('https://dash.cloudflare.com/oauth2/token', data=data,
    headers={'Content-Type': 'application/x-www-form-urlencoded'})

try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
    
    new_token = result.get('access_token', '')
    new_refresh = result.get('refresh_token', refresh_token)
    expires_in = result.get('expires_in', 3600)
    
    print(f"New token: {new_token[:20]}...")
    print(f"Expires in: {expires_in}s")
    
    # Update toml file
    from datetime import datetime, timezone, timedelta
    exp_time = (datetime.now(timezone.utc) + timedelta(seconds=expires_in)).strftime('%Y-%m-%dT%H:%M:%S.000Z')
    
    new_content = content
    # Replace oauth_token
    import re
    new_content = re.sub(r'oauth_token = ".*?"', f'oauth_token = "{new_token}"', new_content)
    new_content = re.sub(r'expiration_time = ".*?"', f'expiration_time = "{exp_time}"', new_content)
    new_content = re.sub(r'refresh_token = ".*?"', f'refresh_token = "{new_refresh}"', new_content)
    
    with open(toml_path, 'w') as f:
        f.write(new_content)
    
    print(f"Token updated! Expires: {exp_time}")
    
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"HTTP Error {e.code}: {body[:300]}")
except Exception as e:
    print(f"Error: {e}")
