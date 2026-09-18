"""
Modular, robust codebase audit and 3D Digital Twin verification using Claude Opus 5 Thinking (TabiToken).
"""
import os
import sys
import json
import time
from pathlib import Path
try:
    import httpx
    HAS_HTTPX = True
except ImportError:
    HAS_HTTPX = False
    import urllib.request

sys.stdout.reconfigure(encoding="utf-8")

BASE_URL = "https://tabitoken.com/v1/chat/completions"
API_KEY = "sk-mMpYrR7SFwnC0O8GkpY8ps5zDAywf0T66iK02kYbdhmKfwZm"
IDENT = "Nud2uKoJHg9AlSa8EVl4+4o44swe/IA="
MODEL = "claude-opus-5-thinking"
PROJECT_ROOT = Path(r"c:\Soobshio_project")

def ask_opus5(system_prompt: str, user_prompt: str, max_tokens: int = 4000) -> str:
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "max_tokens": max_tokens,
        "temperature": 0.2
    }
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "User-Agent": "Antigravity/1.0",
        "X-Ident": IDENT,
        "Identification": IDENT,
    }
    
    for attempt in range(1, 4):
        try:
            if HAS_HTTPX:
                with httpx.Client(timeout=120.0) as client:
                    resp = client.post(BASE_URL, json=payload, headers=headers)
                    resp.raise_for_status()
                    data = resp.json()
                    return data["choices"][0]["message"]["content"]
            else:
                req = urllib.request.Request(BASE_URL, data=json.dumps(payload).encode("utf-8"), headers=headers)
                with urllib.request.urlopen(req, timeout=120) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                    return data["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"  [Attempt {attempt}] Error: {e}")
            time.sleep(2)
    raise RuntimeError(f"Failed to query {MODEL} after 3 attempts")

def main():
    print("=" * 60)
    print("City Pulse — Modular Audit & 3D Twin Architecture via Claude Opus 5 Thinking")
    print("=" * 60)
    
    sections = {}
    
    # 1. Security & Auth Audit
    print("\n[1/3] Running Security & Auth Deep Dive...")
    sec_context = (
        "### Backend security.py:\n" + (PROJECT_ROOT / "services/Backend/security.py").read_text(encoding="utf-8", errors="replace")[:3000] +
        "\n\n### Auth auth.py:\n" + (PROJECT_ROOT / "services/data_layer/auth.py").read_text(encoding="utf-8", errors="replace")[:3000] +
        "\n\n### Complaints router complaints.py:\n" + (PROJECT_ROOT / "services/Backend/routers/complaints.py").read_text(encoding="utf-8", errors="replace")[:3000]
    )
    sec_prompt = "Проведи детальный аудит безопасности (P0-P3 уязвимости, JWT токены, Telegram WebApp HMAC, IDOR, права доступа) по предоставленному коду. Дай конкретные исправления."
    sections["security"] = ask_opus5("Ты главный аудитор по безопасности.", sec_prompt + "\n\n" + sec_context)
    print("  -> Security section complete.")

    # 2. Performance, API & Architecture
    print("\n[2/3] Running Architecture & Performance Deep Dive...")
    arch_context = (
        "### Backend app.py:\n" + (PROJECT_ROOT / "services/Backend/app.py").read_text(encoding="utf-8", errors="replace")[:4000] +
        "\n\n### Docker-compose:\n" + (PROJECT_ROOT / "docker-compose.yml").read_text(encoding="utf-8", errors="replace")[:2500] +
        "\n\n### Requirements:\n" + (PROJECT_ROOT / "requirements.txt").read_text(encoding="utf-8", errors="replace")[:1500]
    )
    arch_prompt = "Оцени общую архитектуру FastAPI + Docker + Postgres + Redis: асинхронность, пулы соединений, миграции, логирование, устойчивость к нагрузкам."
    sections["architecture"] = ask_opus5("Ты главный системный архитектор.", arch_prompt + "\n\n" + arch_context)
    print("  -> Architecture section complete.")

    # 3. 3D Digital Twin Implementation Strategy
    print("\n[3/3] Running 3D Digital Twin (OSM + ArcticDEM 2m + Sentinel-2) Blueprint...")
    twin_context = (
        "Город: Нижневартовск (60.9397°N, 76.5683°E), ХМАО-Югра.\n"
        "Стек: FastAPI backend + Flutter MapLibre GL Native / WebGL + Protomaps PMTiles.\n"
        "Источники данных: OpenStreetMap здания (22k полигонов), ArcticDEM 2м / Copernicus GLO-30 (рельеф), Sentinel-2 TCI (Tile T43VBN), City Pulse 130+ камер и гидропост реки Обь."
    )
    twin_prompt = """Спроектируй эталонную архитектуру 3D Digital Twin для Нижневартовска:
1. Алгоритм импутации высот зданий (height = levels * 3.0 + 1.2, классификация по типам зданий).
2. Модель динамического паводка реки Обь (симуляция уровней 800 - 1050 см, расчёт зон затопления СОНТ и Старого Вартовска).
3. 3D маркеры и конусы обзора камер (FOV cones).
4. REST API контракты для FastAPI роутера /api/v1/3d-twin.
5. Интеграция с Flutter (MapLibre 3D fill-extrusion)."""
    sections["digital_twin"] = ask_opus5("Ты ведущий эксперт по GIS и 3D Digital Twins.", twin_prompt + "\n\n" + twin_context)
    print("  -> 3D Digital Twin section complete.")

    # Combine into comprehensive report
    full_report = f"""# City Pulse — Полный аудит и архитектура 3D Digital Twin
**Модель:** `claude-opus-5-thinking` (TabiToken API)  
**Дата аудита:** 23 августа 2026  
**Проект:** Пульс Города (City Pulse) — Нижневартовск  

---

## 1. 🛡️ Безопасность и защита данных (Security Audit)
{sections['security']}

---

## 2. ⚡ Архитектура, производительность и стек (System Architecture)
{sections['architecture']}

---

## 3. 🗺️ Эталонная архитектура 3D Digital Twin Нижневартовска
{sections['digital_twin']}

---
"""
    report_path = PROJECT_ROOT / ".omc" / "plans" / "claude_opus_5_thinking_audit.md"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(full_report, encoding="utf-8")

    artifact_path = Path(r"C:\Users\рс\.gemini\antigravity\brain\196a6a60-78da-4074-9736-796b8601132e\claude_opus_5_thinking_audit.md")
    artifact_path.write_text(full_report, encoding="utf-8")

    print("\n" + "=" * 60)
    print("Audit & Architecture Report Generated Successfully!")
    print(f"Saved to:\n- {report_path}\n- {artifact_path}")
    print("=" * 60)

if __name__ == "__main__":
    main()
