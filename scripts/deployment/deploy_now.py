"""Update GitHub CF_API_TOKEN and trigger deploy via SOCKS5 proxy"""
import ctypes, ctypes.wintypes, json, os, socket, ssl, struct

# === SOCKS5 proxy ===
PROXY_HOST = "46.183.30.125"
PROXY_PORT = 14520
PROXY_USER = "user360810"
PROXY_PASS = "0dkmyj"

def socks5_connect(target_host, target_port, timeout=15):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect((PROXY_HOST, PROXY_PORT))
    s.send(b"\x05\x01\x02")
    s.recv(2)
    auth = b"\x01" + bytes([len(PROXY_USER)]) + PROXY_USER.encode()
    auth += bytes([len(PROXY_PASS)]) + PROXY_PASS.encode()
    s.send(auth)
    ar = s.recv(2)
    if ar[1] != 0:
        raise Exception("SOCKS5 auth failed")
    req = b"\x05\x01\x00\x03" + bytes([len(target_host)]) + target_host.encode()
    req += struct.pack("!H", target_port)
    s.send(req)
    resp = s.recv(10)
    if resp[1] != 0:
        raise Exception(f"SOCKS5 connect failed: {resp[1]}")
    return s

def https_request(host, method, path, body=None, headers=None, timeout=15):
    raw = socks5_connect(host, 443, timeout)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    s = ctx.wrap_socket(raw, server_hostname=host)
    
    hdrs = headers or {}
    hdrs["Host"] = host
    hdrs["Connection"] = "close"
    if body and "Content-Type" not in hdrs:
        hdrs["Content-Type"] = "application/json"
    
    req = f"{method} {path} HTTP/1.1\r\n"
    for k, v in hdrs.items():
        req += f"{k}: {v}\r\n"
    if body:
        req += f"Content-Length: {len(body)}\r\n"
    req += "\r\n"
    
    s.send(req.encode())
    if body:
        s.send(body if isinstance(body, bytes) else body.encode())
    
    data = b""
    while True:
        try:
            chunk = s.recv(8192)
            if not chunk: break
            data += chunk
        except: break
    s.close()
    
    header_end = data.find(b"\r\n\r\n")
    resp_headers = data[:header_end].decode("utf-8", errors="ignore") if header_end > 0 else ""
    resp_body = data[header_end + 4:] if header_end > 0 else data
    status_line = resp_headers.split("\r\n")[0] if resp_headers else ""
    status = int(status_line.split(" ")[1]) if " " in status_line else 0
    
    return status, resp_body

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
gh_headers = {
    "Authorization": f"token {gh_token}",
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "deploy"
}

# Get public key
status, body = https_request("api.github.com", "GET",
    "/repos/herzo300/pulsenv/actions/secrets/public-key",
    headers=gh_headers)
print(f"Public key: {status}")
pk_data = json.loads(body)

# Encrypt secret
import base64
from nacl import encoding, public
public_key = public.PublicKey(pk_data['key'].encode("utf-8"), encoding.Base64Encoder())
sealed_box = public.SealedBox(public_key)
encrypted = sealed_box.encrypt(cf_token.encode("utf-8"))
encrypted_b64 = base64.b64encode(encrypted).decode("utf-8")

# Update secret
payload = json.dumps({"encrypted_value": encrypted_b64, "key_id": pk_data['key_id']})
status2, _ = https_request("api.github.com", "PUT",
    "/repos/herzo300/pulsenv/actions/secrets/CF_API_TOKEN",
    body=payload, headers=gh_headers)
print(f"Secret updated: {status2}")

# === Trigger workflow ===
status3, _ = https_request("api.github.com", "POST",
    "/repos/herzo300/pulsenv/actions/workflows/deploy-worker.yml/dispatches",
    body=json.dumps({"ref": "main"}), headers=gh_headers)
print(f"Workflow triggered: {status3}")
print("Done! Check https://github.com/herzo300/pulsenv/actions")
