"""Check GitHub Actions workflow status via SOCKS5"""
import socket, ssl, struct, json

def socks5_get(host, path, headers=None):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect(("46.183.30.125", 14520))
    s.send(b"\x05\x01\x02")
    s.recv(2)
    s.send(b"\x01\x0auser360810\x060dkmyj")
    s.recv(2)
    req = b"\x05\x01\x00\x03" + bytes([len(host)]) + host.encode() + struct.pack("!H", 443)
    s.send(req)
    s.recv(10)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    ss = ctx.wrap_socket(s, server_hostname=host)
    
    hdrs = headers or {}
    hdrs["Host"] = host
    hdrs["Connection"] = "close"
    hdrs["User-Agent"] = "check"
    
    h = f"GET {path} HTTP/1.1\r\n"
    for k, v in hdrs.items():
        h += f"{k}: {v}\r\n"
    h += "\r\n"
    ss.send(h.encode())
    
    data = b""
    while True:
        try:
            chunk = ss.recv(8192)
            if not chunk: break
            data += chunk
        except: break
    ss.close()
    
    body = data.split(b"\r\n\r\n", 1)[1] if b"\r\n\r\n" in data else data
    return json.loads(body)

# Get GH token
import ctypes, ctypes.wintypes
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
advapi32.CredReadW('git:https://github.com', 1, 0, ctypes.byref(cred))
blob = ctypes.string_at(cred.contents.CredentialBlob, cred.contents.CredentialBlobSize)
gh_token = blob.decode('utf-16-le') if b'\x00' in blob else blob.decode('utf-8')
advapi32.CredFree(cred)

headers = {
    "Authorization": f"token {gh_token}",
    "Accept": "application/vnd.github.v3+json"
}

# Check latest workflow runs
data = socks5_get("api.github.com", "/repos/herzo300/pulsenv/actions/runs?per_page=5", headers)
runs = data.get("workflow_runs", [])
print(f"Total runs: {data.get('total_count', 0)}")
for run in runs[:5]:
    print(f"  [{run['status']}] {run['conclusion'] or '...'} | {run['name']} | {run['created_at']} | ID: {run['id']}")
