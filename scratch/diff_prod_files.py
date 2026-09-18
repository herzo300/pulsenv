#!/usr/bin/env python3
import paramiko, hashlib
from pathlib import Path

VPS = ("45.153.68.59", 22, "root", "sf?UQ8AYk*-DB8")
PAIRS = [
    ("services/rag_city_assistant.py", "/opt/soobshio/services/rag_city_assistant.py"),
    ("services/rag_city_assistant.py", "/opt/soobshio/services/Backend/services/rag_city_assistant.py"),
    ("services/Backend/routers/dispatcher.py", "/opt/soobshio/services/Backend/routers/dispatcher.py"),
]
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(VPS[0], VPS[1], VPS[2], VPS[3], timeout=30)
sftp = ssh.open_sftp()
for local, remote in PAIRS:
    try:
        with sftp.open(remote) as f:
            rh = hashlib.md5(f.read()).hexdigest()
    except Exception as e:
        rh = f"MISSING({e.__class__.__name__})"
    lh = hashlib.md5(Path(local).read_bytes()).hexdigest() if Path(local).exists() else "LOCAL_MISSING"
    print(("DIFF " if lh != rh else "SAME ") + f"{remote}\n   local={lh[:8]} remote={rh[:8] if isinstance(rh,str) else rh}")
sftp.close(); ssh.close()
