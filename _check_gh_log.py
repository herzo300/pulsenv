"""Check GitHub Actions workflow log — using urllib (no httpx)"""
import json, ctypes, ctypes.wintypes, urllib.request, io, zipfile

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
    print("No credential"); exit(1)
blob = ctypes.string_at(cred.contents.CredentialBlob, cred.contents.CredentialBlobSize)
token = blob.decode('utf-16-le') if b'\x00' in blob else blob.decode('utf-8')
advapi32.CredFree(cred)
print(f"Token: {token[:8]}...")

headers = {'Authorization': f'token {token}', 'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'check'}

# Get latest failed run
req = urllib.request.Request('https://api.github.com/repos/herzo300/pulsenv/actions/runs?per_page=1', headers=headers)
with urllib.request.urlopen(req) as resp:
    runs = json.loads(resp.read())['workflow_runs']

if not runs:
    print("No runs"); exit(1)
run = runs[0]
print(f"Run #{run['id']}: status={run['status']} conclusion={run['conclusion']} created={run['created_at']}")

# Get jobs
req2 = urllib.request.Request(run['jobs_url'], headers=headers)
with urllib.request.urlopen(req2) as resp2:
    jobs = json.loads(resp2.read())['jobs']
for job in jobs:
    print(f"Job: {job['name']} conclusion={job['conclusion']}")
    for step in job.get('steps', []):
        print(f"  Step: {step['name']} conclusion={step['conclusion']}")

# Download logs
log_url = f"https://api.github.com/repos/herzo300/pulsenv/actions/runs/{run['id']}/logs"
req3 = urllib.request.Request(log_url, headers=headers)
try:
    with urllib.request.urlopen(req3) as resp3:
        z = zipfile.ZipFile(io.BytesIO(resp3.read()))
        for name in z.namelist():
            content = z.read(name).decode('utf-8', errors='replace')
            lines = content.strip().split('\n')
            print(f"\n=== {name} (last 40 lines) ===")
            for line in lines[-40:]:
                print(line)
except Exception as e:
    print(f"Log download error: {e}")
