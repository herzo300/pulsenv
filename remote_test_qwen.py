import json, urllib.request, sys, time, base64, subprocess

OLLAMA_URL = "http://localhost:11434"
try:
    result = subprocess.run(
        ["docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", "soobshio_ollama"],
        capture_output=True, text=True, check=True
    )
    ollama_ip = result.stdout.strip()
    if ollama_ip: OLLAMA_URL = f"http://{ollama_ip}:11434"
except Exception as e:
    pass

print(f"Testing Qwen via Ollama natively at {OLLAMA_URL}\n", flush=True)

# 1. Text Analysis (Complaints)
complaints = [
    ("На улице Дзержинского возле 15 школы открыт люк! Кто-нибудь провалится!", "открытый люк/ЧП"),
    ("Вчера вечером на перекрестке Ленина и Кузоваткина маршрутка врезалась в легковушку. Скорые стояли", "ДТП"),
    ("Продам гараж в ГСК 'Авиатор', недорого. Писать в личку.", "объявление (не проблема)"),
    ("Мусорные баки на Чапаева 83 забиты под завязку, ветер разносит пакеты по всему двору, вонь страшная.", "мусор"),
]

prompt_tmpl = (
    "Определи, является ли это сообщением о городской проблеме. "
    'Верни только JSON: {"relevant":true/false,"category":"...","address":"...или null",'
    '"summary":"краткое описание до 12 слов","severity":1/2/3,"priority":"низкий/средний/высокий"}. '
    "Категории: ЖКХ, Дороги, Бытовой мусор, Транспорт, Благоустройство, Безопасность, Лифты и подъезды, ЧП, Прочее. "
    "Сообщение: "
)

print("=== ТЕКСТОВЫЙ АНАЛИЗ (Qwen 2.5 3B) ===", flush=True)

for i, (complaint, expected) in enumerate(complaints, 1):
    payload = {
        "model": "qwen2.5:3b",
        "prompt": prompt_tmpl + complaint,
        "format": "json",
        "stream": False,
        "options": {"temperature": 0.0, "num_predict": 150}
    }
    
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    
    print(f"\n[Текст {i}] Ожидание: {expected}")
    print(f"Вход: {complaint}")
    try:
        t0 = time.time()
        with urllib.request.urlopen(req, timeout=300) as resp:
            raw = resp.read().decode("utf-8")
        elapsed = time.time() - t0
        
        reply = json.loads(raw).get("response", "")
        print(f"Ответ ({elapsed:.1f} сек): {reply}", flush=True)
    except Exception as e:
        print(f"ERROR: {e}", flush=True)

# 2. Vision Analysis
print("\n=== ВИЗУАЛЬНЫЙ АНАЛИЗ КАМЕР (Qwen 2.5 ViL 3B) ===", flush=True)
test_image_url = "https://raw.githubusercontent.com/ultralytics/yolov5/master/data/images/bus.jpg"
image_b64 = ""
try:
    req_img = urllib.request.Request(test_image_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req_img, timeout=10) as response:
        image_bytes = response.read()
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
except Exception as e:
    print(f"Failed to fetch image: {e}")

if image_b64:
    vision_prompt = (
        "Analyze this city surveillance camera image. "
        "Is there a problem? Types: dump (garbage), accident (car crash), "
        "flood (water), smoke (fire/smoke), animals (stray dogs), none (normal). "
        'Return ONLY JSON: {"event_type":"none|dump|accident|flood|smoke|animals",'
        '"confidence":0.0-1.0,"description":"brief description or null"}'
    )

    payload_vision = {
        "model": "qwen2.5vl:3b",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": vision_prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}}
                ]
            }
        ],
        "temperature": 0.1,
        "stream": False
    }

    req_vision = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=json.dumps(payload_vision).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

    print("\nОтправка изображения в qwen2.5vl:3b...", flush=True)
    try:
        t0 = time.time()
        with urllib.request.urlopen(req_vision, timeout=500) as resp:
            raw = resp.read().decode("utf-8")
        elapsed = time.time() - t0
        reply = json.loads(raw).get("message", {}).get("content", "")
        print(f"Ответ ({elapsed:.1f} сек): {reply}", flush=True)
    except Exception as e:
        print(f"ERROR: {e}", flush=True)

print("\n--- Проверка завершена! ---")
