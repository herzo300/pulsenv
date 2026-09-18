import os
import sys
import json
import time
import re
import urllib.parse
import urllib.request
import sqlite3
from pathlib import Path
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(r"C:\Soobshio_project")
load_dotenv(PROJECT / ".env")

OPENROUTER_KEY = os.getenv("OPENROUTER_API_KEY", "").strip()

# Target static directory for 2K complaint images
UPLOADS_DIR = PROJECT / "public" / "signals_2k"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

print("=" * 65)
print("  Генератор высококачественных 2K фото для сигналов города")
print("=" * 65)

def ask_kimi_k3_for_prompt(title: str, category: str, address: str, desc: str) -> str:
    """Uses Kimi K3 via OpenRouter to generate ultra-realistic 2K photo prompt."""
    sys_prompt = (
        "You are an expert AI photographer and urban photojournalist. "
        "Create an ultra-photorealistic, documentary photo prompt in English for a real municipal incident "
        "or event in the Siberian city of Nizhnevartovsk, Russia. "
        "Describe the exact visual scene, framing, textures (asphalt, concrete, Siberian weather, multi-story Russian panel houses), "
        "and camera settings (e.g., 'Documentary photograph shot on Sony A7R IV, 35mm f/2.0 lens, sharp focus, natural daylight, photorealistic textures, 2K resolution, realistic urban scene, no text, no watermark, no CGI, no cartoon'). "
        "Return ONLY the plain English prompt text without explanations or quotes."
    )
    user_prompt = f"City: Nizhnevartovsk\nCategory: {category}\nTitle: {title}\nAddress: {address}\nContext: {desc[:200]}"
    
    if not OPENROUTER_KEY:
        # Fallback realistic prompt builder
        return f"Documentary photo taken on Sony A7R IV, 35mm f/2.0 lens, {title}, category {category} at {address} Nizhnevartovsk city street, natural lighting, realistic pavement, Russian apartment buildings background, high resolution 2K, sharp details, real photograph, no CGI"

    req_data = {
        "model": "moonshotai/kimi-k3",
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 150
    }
    
    try:
        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENROUTER_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://pulsgoroda.ru",
                "X-Title": "CityPulse 2K Photography"
            },
            data=json.dumps(req_data).encode("utf-8")
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            content = data["choices"][0]["message"]["content"].strip()
            # Clean quotes if any
            content = re.sub(r'^["\']|["\']$', '', content).strip()
            return content
    except Exception as e:
        print(f"  [Warn] OpenRouter prompt generation fallback: {e}")
        return f"Documentary realistic photo of {title}, {category} in Nizhnevartovsk street {address}, 35mm lens, natural daylight, authentic Siberian urban details, 2K resolution, crisp textures, realistic photo"


def generate_and_save_2k_photo(report_id: int, prompt: str) -> str:
    """Generates a 2K (1920x1080) high-fidelity photo and saves locally."""
    clean_prompt = prompt.replace("\n", " ").strip()
    encoded = urllib.parse.quote(clean_prompt)
    seed = int(time.time() * 1000) % 100000000 + report_id * 73
    
    # 2K Resolution URL (1920x1080) with FLUX High Detail Realism & no logo
    photo_url = f"https://image.pollinations.ai/prompt/{encoded}?width=1920&height=1080&seed={seed}&model=flux-realism&nologo=true&enhance=true"
    
    local_file = UPLOADS_DIR / f"report_{report_id}_2k.jpg"
    try:
        req = urllib.request.Request(photo_url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            img_data = resp.read()
            if len(img_data) > 10000:
                with open(local_file, "wb") as f:
                    f.write(img_data)
                print(f"  ✓ Сохранено локально: report_{report_id}_2k.jpg ({len(img_data)//1024} КБ, 1920x1080 2K)")
                return f"http://45.153.68.59/static/uploads/complaints/report_{report_id}_2k.jpg"
    except Exception as e:
        print(f"  [Notice] Прямое скачивание 2K ассета: {e}, используем прямой 2K CDN URL")
    
    return photo_url


def main():
    conn = sqlite3.connect(PROJECT / "soobshio.db")
    cur = conn.cursor()
    cur.execute("SELECT id, title, category, address, description FROM reports")
    reports = cur.fetchall()
    
    total = len(reports)
    print(f"Найдено {total} сигналов для генерации 2K фото...")
    
    total_tokens_used = 0
    updated_count = 0
    
    for idx, (rep_id, title, cat, addr, desc) in enumerate(reports, 1):
        print(f"\n[{idx}/{total}] Сигнал #{rep_id}: {title} ({cat})")
        
        # 1. Генерируем фотореалистичный 2K промпт через Kimi K3
        photo_prompt = ask_kimi_k3_for_prompt(title, cat, addr or "Нижневартовск", desc or "")
        print(f"  Промпт 2K: {photo_prompt[:85]}...")
        
        # 2. Генерируем 2K фото
        new_photo_url = generate_and_save_2k_photo(rep_id, photo_prompt)
        
        # 3. Очищаем старые ссылки и вставляем новое 2K фото
        clean_desc = desc or ""
        clean_desc = re.sub(r"Фото:\s*https?://[^\s\]\n]+", "", clean_desc).strip()
        clean_desc = re.sub(r"https?://image\.pollinations\.ai[^\s\]\n]+", "", clean_desc).strip()
        
        updated_desc = f"{clean_desc}\n\nФото: {new_photo_url}".strip()
        
        cur.execute("UPDATE reports SET description = ? WHERE id = ?", (updated_desc, rep_id))
        updated_count += 1
        total_tokens_used += 120 # ~120 токенов на Kimi K3 запрос
        
        time.sleep(0.3)
    
    conn.commit()
    conn.close()
    
    print("\n" + "=" * 65)
    print(f"  УСПЕШНО ОБНОВЛЕНО: {updated_count} сигналов с 2K фото высокого разрешения!")
    print(f"  Модели: moonshotai/kimi-k3 (OpenRouter) + FLUX Realism 2K Ultra (1920x1080)")
    print(f"  Затраты на текущую генерацию (37 сигналов): ~${(total_tokens_used * 0.0000008 + 37 * 0.004):.4f} (~15 руб)")
    print("=" * 65)

if __name__ == "__main__":
    main()
