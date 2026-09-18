import base64
import json
import subprocess
import time
import urllib.request


DEFAULT_OLLAMA_URL = "http://localhost:11434"
TEXT_MODEL = "qwen2.5:3b"
VISION_MODEL = "qwen2.5vl:3b"

COMPLAINTS = [
    (
        "На улице Дзержинского возле 15 школы открыт люк! Кто-нибудь провалится!",
        "открытый люк/ЧП",
    ),
    (
        "Вчера вечером на перекрестке Ленина и Кузоваткина маршрутка врезалась в легковушку. Скорые стояли",
        "ДТП",
    ),
    (
        "Продам гараж в ГСК 'Авиатор', недорого. Писать в личку.",
        "объявление (не проблема)",
    ),
    (
        "Мусорные баки на Чапаева 83 забиты под завязку, ветер разносит пакеты по всему двору, вонь страшная.",
        "мусор",
    ),
]

PROMPT_TEMPLATE = (
    "Определи, является ли это сообщением о городской проблеме. "
    'Верни только JSON: {"relevant":true/false,"category":"...","address":"...или null",'
    '"summary":"краткое описание до 12 слов","severity":1/2/3,'
    '"priority":"низкий/средний/высокий"}. '
    "Категории: ЖКХ, Дороги, Бытовой мусор, Транспорт, Благоустройство, "
    "Безопасность, Лифты и подъезды, ЧП, Прочее. "
    "Сообщение: "
)


def resolve_ollama_url() -> str:
    try:
        result = subprocess.run(
            [
                "docker",
                "inspect",
                "-f",
                "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}",
                "soobshio_ollama",
            ],
            capture_output=True,
            text=True,
            check=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return DEFAULT_OLLAMA_URL

    ollama_ip = result.stdout.strip()
    return f"http://{ollama_ip}:11434" if ollama_ip else DEFAULT_OLLAMA_URL


def read_url(request: urllib.request.Request, timeout: int) -> str:
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def run_text_checks(ollama_url: str) -> None:
    print(f"=== ТЕКСТОВЫЙ АНАЛИЗ ({TEXT_MODEL}) ===", flush=True)
    for index, (complaint, expected) in enumerate(COMPLAINTS, 1):
        payload = {
            "model": TEXT_MODEL,
            "prompt": PROMPT_TEMPLATE + complaint,
            "format": "json",
            "stream": False,
            "options": {"temperature": 0.0, "num_predict": 150},
        }
        request = urllib.request.Request(
            f"{ollama_url}/api/generate",
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )

        print(f"\n[Текст {index}] Ожидание: {expected}")
        print(f"Вход: {complaint}")
        try:
            started_at = time.time()
            raw = read_url(request, timeout=300)
            elapsed = time.time() - started_at
            reply = json.loads(raw).get("response", "")
            print(f"Ответ ({elapsed:.1f} сек): {reply}", flush=True)
        except Exception as exc:
            print(f"ERROR: {exc}", flush=True)


def run_vision_check(ollama_url: str) -> None:
    print(f"\n=== ВИЗУАЛЬНЫЙ АНАЛИЗ КАМЕР ({VISION_MODEL}) ===", flush=True)
    image_request = urllib.request.Request(
        "https://raw.githubusercontent.com/ultralytics/yolov5/master/data/images/bus.jpg",
        headers={"User-Agent": "Mozilla/5.0"},
    )
    try:
        with urllib.request.urlopen(image_request, timeout=10) as response:
            image_b64 = base64.b64encode(response.read()).decode("utf-8")
    except Exception as exc:
        print(f"Failed to fetch image: {exc}")
        return

    payload = {
        "model": VISION_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            "Analyze this city surveillance camera image. "
                            "Is there a problem? Types: dump, accident, flood, smoke, animals, none. "
                            'Return ONLY JSON: {"event_type":"none|dump|accident|flood|smoke|animals",'
                            '"confidence":0.0-1.0,"description":"brief description or null"}'
                        ),
                    },
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "temperature": 0.1,
        "stream": False,
    }
    request = urllib.request.Request(
        f"{ollama_url}/api/chat",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )

    print("\nОтправка изображения в qwen2.5vl:3b...", flush=True)
    try:
        started_at = time.time()
        raw = read_url(request, timeout=500)
        elapsed = time.time() - started_at
        reply = json.loads(raw).get("message", {}).get("content", "")
        print(f"Ответ ({elapsed:.1f} сек): {reply}", flush=True)
    except Exception as exc:
        print(f"ERROR: {exc}", flush=True)


def main() -> None:
    ollama_url = resolve_ollama_url()
    print(f"Testing Qwen via Ollama natively at {ollama_url}\n", flush=True)
    run_text_checks(ollama_url)
    run_vision_check(ollama_url)
    print("\n--- Проверка завершена! ---")


if __name__ == "__main__":
    main()
