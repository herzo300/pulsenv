import os
import sys
from pathlib import Path

import paramiko


REMOTE_TEST_SCRIPT = Path(__file__).with_name("remote_test_qwen.py")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ssh_password = os.environ.get("SSH_PASSWORD")
    if not ssh_password:
        raise RuntimeError("SSH_PASSWORD is required to run this remote diagnostic")

    script_content = REMOTE_TEST_SCRIPT.read_text(encoding="utf-8")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("45.153.68.59", username="root", password=ssh_password)

    print("Uploading Qwen test to remote...")
    sftp = ssh.open_sftp()
    with sftp.file("/tmp/remote_test_qwen.py", "w") as remote_file:
        remote_file.write(script_content.encode("utf-8"))
    sftp.close()

    print("Running...")
    channel = ssh.get_transport().open_session()
    channel.settimeout(600)
    channel.exec_command("python3 /tmp/remote_test_qwen.py")

    try:
        while True:
            chunk = channel.recv(8192)
            if not chunk:
                break
            sys.stdout.buffer.write(chunk)
            sys.stdout.flush()

        err_chunk = channel.recv_stderr(8192)
        if err_chunk:
            sys.stderr.buffer.write(err_chunk)
            sys.stderr.flush()
    except Exception as exc:
        print("Error:", exc)
    finally:
        ssh.close()


if __name__ == "__main__":
    main()
