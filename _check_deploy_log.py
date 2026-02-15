"""Check latest GitHub Actions workflow run log"""
import ctypes, ctypes.wintypes, json, urllib.request

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
token = blob.decode('utf-16-le') if b'\x00' in blob else blob.decode('utf-8')
advapi32.CredFree(cred)

headers = {'Authorization': f'token {token}', 'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'check'}

# Get latest successful run
req = urllib.request.Request('https://api.github.com/repos/herzo300/pulsenv/actions/runs?status=success&per_page=1', headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    run = data['workflow_runs'][0]
    run_id = run['id']
    print(f"Run: {run_id}, created: {run['created_at']}, status: {run['status']}, conclusion: {run['conclusion']}")

# Get jobs
req2 = urllib.request.Request(f'https://api.github.com/repos/herzo300/pulsenv/actions/runs/{run_id}/jobs', headers=headers)
with urllib.request.urlopen(req2) as resp2:
    jobs = json.loads(resp2.read())
    for job in jobs['jobs']:
        print(f"\nJob: {job['name']}, status: {job['status']}, conclusion: {job['conclusion']}")
        for step in job['steps']:
            print(f"  Step: {step['name']}, status: {step['status']}, conclusion: {step['conclusion']}")
