"""Check UK catalog names and test cache lookup."""
import os, sys
import paramiko
from dotenv import load_dotenv

load_dotenv(r"C:\Soobshio_project\.env")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname="45.153.68.59", username="root",
            password=os.getenv("SSH_PASSWORD", "").strip(),
            timeout=15, look_for_keys=False, allow_agent=False)

cmds = [
    # List UK names from catalog
    """docker exec soobshio_backend python3 -c "
import json
cache = json.load(open('/app/data/geocode_cache.json', encoding='utf-8'))
print(f'Cache entries: {len(cache)}')
keys = list(cache.keys())[:10]
for k in keys:
    print(f'  Key: {repr(k)} -> {cache[k]}')
" 2>&1""",
    # Check what the catalog endpoint returns for UK names
    """curl -s http://localhost/api/uk/catalog | python3 -c "
import json, sys
data = json.load(sys.stdin)
companies = data.get('companies', [])
print(f'Total companies: {len(companies)}')
for c in companies[:5]:
    name = c.get('name', 'N/A')
    mkd = c.get('mkd', [])
    total_buildings = sum(len(m.get('buildings', [])) for m in mkd)
    print(f'  UK: {repr(name)}, MKD blocks: {len(mkd)}, buildings: {total_buildings}')
" 2>&1""",
    # Test with first UK name directly
    """curl -s 'http://localhost/api/uk/catalog' | python3 -c "
import json, sys, urllib.parse
data = json.load(sys.stdin)
companies = data.get('companies', [])
if companies:
    name = companies[0].get('name', '')
    encoded = urllib.parse.quote(name)
    print(f'Testing with: {repr(name)}')
    print(f'URL encoded: {encoded}')
" 2>&1""",
]

for cmd in cmds:
    print(f"\n{'='*60}")
    _, o, e = ssh.exec_command(cmd, timeout=15)
    o.channel.recv_exit_status()
    out = o.read().decode("utf-8", errors="replace").strip()
    err = e.read().decode("utf-8", errors="replace").strip()
    if out: print(out)
    if err and "error" in err.lower(): print(f"ERR: {err}")

ssh.close()
