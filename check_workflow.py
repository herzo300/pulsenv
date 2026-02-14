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
req = urllib.request.Request('https://api.github.com/repos/herzo300/pulsenv/actions/runs?per_page=3', headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    for run in data['workflow_runs'][:3]:
        status = run['status']
        conclusion = run['conclusion'] or '...'
        name = run['name']
        created = run['created_at']
        print(f"{status:12} {conclusion:12} {name:25} {created}")
