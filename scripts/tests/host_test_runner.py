import os
import sys

import paramiko


SCRIPT_CONTENT = r"""
import json, urllib.request, time, subprocess

OLLAMA_URL = "http://localhost:11434"
try:
    result = subprocess.run(
        ["docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", "soobshio_ollama"],
        capture_output=True, text=True, check=True
    )
    ollama_ip = result.stdout.strip()
    if ollama_ip:
        OLLAMA_URL = f"http://{ollama_ip}:11434"
except Exception:
    pass

model_name = "gemma4:e2b"
print(f"Testing {model_name} at {OLLAMA_URL}", flush=True)

complaints = [
    ("На улице Мира 62 уже 3 день не вывозят мусор, контейнеры переполнены, мусор разносит по двору", "мусор"),
    ("На проспекте Победы сбили пешехода на зебре, скорая уже на месте", "ДТП"),
    ("Продаю диван б/у в хорошем состоянии, самовывоз, район 10П", "объявление"),
    ("В подъезде 3 дома по Ленина 48 не работает лифт уже неделю", "лифт"),
    ("Во дворе на Интернациональной 37 задымление, похоже горит мусорный бак", "пожар"),
]

prompt_tmpl = (
    "Определи, является ли это сообщением о городской проблеме. "
    "Верни только JSON: {\"relevant\":true/false,\"category\":\"...\",\"address\":\"...или null\","
    "\"summary\":\"краткое описание до 12 слов\",\"severity\":1/2/3,\"priority\":\"низкий/средний/высокий\"}. "
    "Категории: ЖКХ, Дороги, Бытовой мусор, Транспорт, Благоустройство, Безопасность, Лифты и подъезды, ЧП, Прочее. "
    "Сообщение: "
)

print("Pre-loading model...", flush=True)
try:
    urllib.request.urlopen(urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps({"model": model_name, "prompt": "Hi", "stream": False}).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    ), timeout=120)
except Exception as e:
    print("Preload log:", e)

for i, (complaint, expected) in enumerate(complaints, 1):
    print(f"\n--- Test {i} ({expected}) ---", flush=True)
    payload = json.dumps({
        "model": model_name,
        "prompt": prompt_tmpl + complaint,
        "stream": False,
        "format": "json",
        "options": {"temperature": 0, "num_predict": 200, "num_ctx": 1024}
    }, ensure_ascii=False).encode("utf-8")

    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    try:
        t0 = time.time()
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8")
        elapsed = time.time() - t0
        parsed = json.loads(json.loads(raw).get("response", ""))
        print(
            f"  Result: relevant={parsed.get('relevant')}, category={parsed.get('category')}, addr={parsed.get('address')} ({elapsed:.1f}s)",
            flush=True,
        )
    except Exception as e:
        print(f"  ERROR: {e}", flush=True)

print("\nDone!")
"""


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ssh_password = os.environ.get("SSH_PASSWORD")
    if not ssh_password:
        raise RuntimeError("SSH_PASSWORD is required to run this remote diagnostic")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect("45.153.68.59", username="root", password=ssh_password)

    print("Uploading to remote...")
    sftp = ssh.open_sftp()
    with sftp.file("/tmp/remote_test_real.py", "w") as remote_file:
        remote_file.write(SCRIPT_CONTENT.encode("utf-8"))
    sftp.close()

    print("Running...")
    channel = ssh.get_transport().open_session()
    channel.settimeout(600)
    channel.exec_command("python3 /tmp/remote_test_real.py")
    try:
        while True:
            chunk = channel.recv(8192)
            if not chunk:
                break
            sys.stdout.buffer.write(chunk)
            sys.stdout.flush()
    except TimeoutError:
        print("TIMEOUT!")
    finally:
        ssh.close()


if __name__ == "__main__":
    main()
