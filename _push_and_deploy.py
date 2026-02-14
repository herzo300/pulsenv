"""Pull, push to GitHub and trigger deploy"""
import ctypes, ctypes.wintypes, subprocess, os

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

url = f'https://herzo300:{gh_token}@github.com/herzo300/pulsenv.git'
env = os.environ.copy()
env['GIT_TERMINAL_PROMPT'] = '0'

# Pull first
r = subprocess.run(['git', 'pull', url, 'main', '--rebase'], capture_output=True, text=True, timeout=30, env=env)
print(f'Pull: {r.returncode}')
if r.stderr: print(r.stderr[:300])

# Push
r = subprocess.run(['git', 'push', url, 'main'], capture_output=True, text=True, timeout=30, env=env)
print(f'Push: {r.returncode}')
if r.stdout: print(r.stdout[:200])
if r.stderr: print(r.stderr[:200])
