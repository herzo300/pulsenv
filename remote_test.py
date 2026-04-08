import json, urllib.request, time, sys

OLLAMA_URL = "http://localhost:11434"
# Get IP of ollama container
import subprocess
try:
    result = subprocess.run(
        ["docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", "soobshio_ollama"],
        capture_output=True, text=True, check=True
    )
    ollama_ip = result.stdout.strip()
    if ollama_ip:
        OLLAMA_URL = f"http://{ollama_ip}:11434"
except:
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
    "Определи, является ли это сообщением о городской проблеме в Нижневартовске. "
    "Верни только JSON: {\"relevant\":true/false,\"category\":\"...\",\"address\":\"...или null\","
    "\"summary\":\"краткое описание до 12 слов\",\"severity\":1/2/3,\"priority\":\"низкий/средний/высокий\"}. "
    "Категории: ЖКХ, Дороги, Бытовой мусор, Транспорт, Благоустройство, Безопасность, Лифты и подъезды, ЧП, Прочее. "
    "Сообщение: "
)

# First send an empty request to preload the model into RAM
print("Pre-loading model...", flush=True)
try:
    urllib.request.urlopen(urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps({"model": model_name, "prompt": "Hi", "stream": False}).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    ), timeout=120)
except Exception as e:
    print("Preload error:", e)

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
        rel = parsed.get("relevant")
        cat = parsed.get("category")
        addr = parsed.get("address")
        
        print(f"  Result: relevant={rel}, category={cat}, address={addr} ({elapsed:.1f}s)", flush=True)
    except Exception as e:
        print(f"  ERROR: {e}", flush=True)

print("\nDone!")
