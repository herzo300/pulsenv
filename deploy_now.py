"""Update GitHub CF_API_TOKEN and trigger deploy"""
import ctypes, ctypes.wintypes, json, urllib.request, base64, os

# === Get GitHub token from Windows Credential Manager ===
class CREDENTIAL(ctypes.Structure):
    _fields_ = [
        ('Flags', ctypes.wintypes.DWORD), ('Type', ctypes.wintypes.DWORD),
        ('TargetName', ctypes.wintypes.LPWSTR), ('Comment', ctypes.wintypes.LPWSTR),
        ('LastWritten', ctypes.wintypes.FILETIME), ('CredentialBlobSize', ctypes.wintypes.DWORD),
        ('CredentialBlob', ctypes.POINTER(ctypes.c_byte)), ('Persist', ctypes.wintypes.DWORD),
        ('AttributeCount', ctypes.wintypes.DWORD), ('Attributes', ctypes.c_void_p),
        ('TargetAlias', ctypes.wintypes.LPWSTR), ('UserName', ctypes.wintypes.LPWSTR),
    ]

PCREDENTIAL = ctypes.POINTER(CREDENTIAL)
advapi32 = ctypes.windll.advapi32
advapi32.CredReadW.argtypes = [ctypes.wintypes.LPCWSTR, ctypes.wintypes.DWORD, ctypes.wintypes.DWORD, ctypes.POINTER(PCREDENTIAL)]
advapi32.CredReadW.restype = ctypes.wintypes.BOOL
advapi32.CredFree.argtypes = [ctypes.c_void_p]

cred = PCREDENTIAL()
if not advapi32.CredReadW('git:https://github.com', 1, 0, ctypes.byref(cred)):
    print("ERROR: Cannot read GitHub credential"); exit(1)

blob = ctypes.string_at(cred.contents.CredentialBlob, cred.contents.CredentialBlobSize)
gh_token = blob.decode('utf-16-le') if b'\x00' in blob else blob.decode('utf-8')
advapi32.CredFree(cred)
print(f"GH token: {gh_token[:8]}...")

# === Get CF OAuth token from wrangler config ===
toml_path = os.path.join(os.environ['APPDATA'], 'xdg.config', '.wrangler', 'config', 'default.toml')
with open(toml_path, 'r') as f:
    content = f.read()
cf_token = None
for line in content.split('\n'):
    if line.strip().startswith('oauth_token'):
        cf_token = line.split('"')[1]
        break
print(f"CF token: {cf_token[:20]}...")

# === Update GitHub secret ===
headers = {'Authorization': f'token {gh_token}', 'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'deploy'}

req = urllib.request.Request('https://api.github.com/repos/herzo300/pulsenv/actions/secrets/public-key', headers=headers)
with urllib.request.urlopen(req) as resp:
    pk_data = json.loads(resp.read())

from nacl import encoding, public
public_key = public.PublicKey(pk_data['key'].encode("utf-8"), encoding.Base64Encoder())
sealed_box = public.SealedBox(public_key)
encrypted = sealed_box.encrypt(cf_token.encode("utf-8"))
encrypted_b64 = base64.b64encode(encrypted).decode("utf-8")

payload = json.dumps({"encrypted_value": encrypted_b64, "key_id": pk_data['key_id']}).encode()
req2 = urllib.request.Request(
    'https://api.github.com/repos/herzo300/pulsenv/actions/secrets/CF_API_TOKEN',
    data=payload, headers={**headers, 'Content-Type': 'application/json'}, method='PUT'
)
with urllib.request.urlopen(req2) as resp2:
    print(f"Secret updated: {resp2.status}")

# === Trigger workflow ===
req3 = urllib.request.Request(
    'https://api.github.com/repos/herzo300/pulsenv/actions/workflows/deploy-worker.yml/dispatches',
    data=json.dumps({"ref": "main"}).encode(),
    headers={**headers, 'Content-Type': 'application/json'}, method='POST'
)
with urllib.request.urlopen(req3) as resp3:
    print(f"Workflow triggered: {resp3.status}")
print("Done! Check https://github.com/herzo300/pulsenv/actions")
