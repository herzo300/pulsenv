import json
import subprocess
import time
import urllib.request


DEFAULT_OLLAMA_URL = "http://localhost:11434"
MODEL_NAME = "gemma4:e2b"

COMPLAINTS = [
    (
        "На улице Мира 62 уже 3 день не вывозят мусор, контейнеры переполнены, мусор разносит по двору",
        "мусор",
    ),
    ("На проспекте Победы сбили пешехода на зебре, скорая уже на месте", "ДТП"),
    ("Продаю диван б/у в хорошем состоянии, самовывоз, район 10П", "объявление"),
    ("В подъезде 3 дома по Ленина 48 не работает лифт уже неделю", "лифт"),
    ("Во дворе на Интернациональной 37 задымление, похоже горит мусорный бак", "пожар"),
]

PROMPT_TEMPLATE = (
    "Определи, является ли это сообщением о городской проблеме в Нижневартовске. "
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


def post_generate(ollama_url: str, payload: dict, timeout: int = 120) -> str:
    request = urllib.request.Request(
        f"{ollama_url}/api/generate",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def main() -> None:
    ollama_url = resolve_ollama_url()
    print(f"Testing {MODEL_NAME} at {ollama_url}", flush=True)

    print("Pre-loading model...", flush=True)
    try:
        post_generate(
            ollama_url,
            {"model": MODEL_NAME, "prompt": "Hi", "stream": False},
        )
    except Exception as exc:
        print("Preload error:", exc)

    for index, (complaint, expected) in enumerate(COMPLAINTS, 1):
        print(f"\n--- Test {index} ({expected}) ---", flush=True)
        payload = {
            "model": MODEL_NAME,
            "prompt": PROMPT_TEMPLATE + complaint,
            "stream": False,
            "format": "json",
            "options": {"temperature": 0, "num_predict": 200, "num_ctx": 1024},
        }

        try:
            started_at = time.time()
            raw = post_generate(ollama_url, payload)
            elapsed = time.time() - started_at

            parsed = json.loads(json.loads(raw).get("response", ""))
            print(
                "  Result: "
                f"relevant={parsed.get('relevant')}, "
                f"category={parsed.get('category')}, "
                f"address={parsed.get('address')} ({elapsed:.1f}s)",
                flush=True,
            )
        except Exception as exc:
            print(f"  ERROR: {exc}", flush=True)

    print("\nDone!")


if __name__ == "__main__":
    main()
