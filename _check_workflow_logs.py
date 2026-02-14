"""Check GitHub Actions workflow logs"""
import ctypes, ctypes.wintypes, json, urllib.request, io, zipfile

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

headers = {'Authorization': f'token {gh_token}', 'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'deploy'}

# Get latest failed run
req = urllib.request.Request('https://api.github.com/repos/herzo300/pulsenv/actions/runs?per_page=3', headers=headers)
with urllib.request.urlopen(req) as resp:
    runs = json.loads(resp.read())

for run in runs['workflow_runs']:
    if run['conclusion'] == 'failure':
        run_id = run['id']
        print(f"Run {run_id}: {run['conclusion']} at {run['created_at']}")
        
        # Get jobs
        req2 = urllib.request.Request(f'https://api.github.com/repos/herzo300/pulsenv/actions/runs/{run_id}/jobs', headers=headers)
        with urllib.request.urlopen(req2) as resp2:
            jobs = json.loads(resp2.read())
        
        for job in jobs['jobs']:
            print(f"  Job: {job['name']} - {job['conclusion']}")
            for step in job['steps']:
                print(f"    Step: {step['name']} - {step['conclusion']}")
        
        # Get logs
        try:
            req3 = urllib.request.Request(f'https://api.github.com/repos/herzo300/pulsenv/actions/runs/{run_id}/logs', headers=headers)
            with urllib.request.urlopen(req3) as resp3:
                z = zipfile.ZipFile(io.BytesIO(resp3.read()))
                for name in z.namelist():
                    content = z.read(name).decode('utf-8', errors='replace')
                    # Show last 30 lines
                    lines = content.strip().split('\n')
                    print(f"\n--- {name} (last 20 lines) ---")
                    for line in lines[-20:]:
                        print(line)
        except Exception as e:
            print(f"  Logs error: {e}")
        break
