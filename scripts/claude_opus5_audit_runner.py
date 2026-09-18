"""
Audit script using Claude Opus 5 Thinking (claude-opus-5-thinking) via TabiToken API.
Performs a deep architectural, security, performance, and 3D digital twin readiness audit.
"""
import os
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path

# Ensure UTF-8 stdout
sys.stdout.reconfigure(encoding="utf-8")

BASE_URL = "https://tabitoken.com/v1/chat/completions"
API_KEY = "sk-mMpYrR7SFwnC0O8GkpY8ps5zDAywf0T66iK02kYbdhmKfwZm"
IDENT = "Nud2uKoJHg9AlSa8EVl4+4o44swe/IA="
MODEL = "claude-opus-5-thinking"

PROJECT_ROOT = Path(r"c:\Soobshio_project")

FILES_TO_AUDIT = [
    "services/Backend/app.py",
    "services/Backend/security.py",
    "services/data_layer/auth.py",
    "services/Backend/routers/complaints.py",
    "services/Backend/routers/reports.py",
    "services/Backend/routers/road_works.py",
    "services/Backend/routers/map_data.py",
    "services/Backend/routers/cameras.py",
    "services/Backend/routers/weather_alerts.py",
    "services/Backend/routers/house_community.py",
    "services/Backend/routers/pmtiles_server.py",
    "services/Frontend/lib/main.dart",
    "services/Frontend/lib/services/backend_api_service.dart",
    "docker-compose.yml",
    "requirements.txt"
]

def read_file_chunk(path: Path, max_lines: int = 250) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        if len(lines) > max_lines:
            return "\n".join(lines[:max_lines]) + f"\n\n... [{len(lines) - max_lines} lines truncated]"
        return text
    except Exception as e:
        return f"[Error reading {path}: {e}]"

def build_context() -> str:
    chunks = []
    for rel in FILES_TO_AUDIT:
        fpath = PROJECT_ROOT / rel
        content = read_file_chunk(fpath)
        chunks.append(f"### FILE: {rel}\n```\n{content}\n```\n")
    return "\n---\n".join(chunks)

AUDIT_PROMPT = """Ты — главный системный архитектор и ведущий инженер по информационной безопасности и геопространственным данным (GIS/3D Digital Twins).

Проведи глубокий, критический и всесторонний аудит кодовой базы проекта «Пульс Города» (City Pulse) для города Нижневартовск (ХМАО-Югра, Россия).

## СТРУКТУРА АУДИТА:
1. **ИТОГОВЫЙ ВЕРДИКТ И УРОВЕНЬ ГОТОВНОСТИ (EXECUTIVE SUMMARY)**:
   - Общая оценка архитектуры (1-10)
   - Уровень безопасности (Critical / High / Medium / Low)
   - Готовность к развёртыванию в промышленную эксплуатацию (Ready / Blocked / Action Required)

2. **БЕЗОПАСНОСТЬ И ЗАЩИТА ДАННЫХ (P0-P3)**:
   - Анализ аутентификации (JWT, токены, Telegram WebApp)
   - Контроль доступа (IDOR, подмена user_id)
   - Защита сетевых запросов и прокси (CORS, SSL, SSRF)
   - Управление секретами и хранилищем

3. **ПРОИЗВОДИТЕЛЬНОСТЬ И МАСШТАБИРУЕМОСТЬ**:
   - Асинхронность в FastAPI (блокирующие вызовы, пулы соединений)
   - Кэширование геоданных и тайлов (PMTiles, Redis)
   - Мобильный рендеринг (Flutter MapLibre, память, FPS)

4. **АРХИТЕКТУРНЫЙ ПЛАН И РЕКОМЕНДАЦИИ ПО 3D DIGITAL TWIN**:
   - Оценка интеграции OpenStreetMap (импутация высот зданий по формуле height = levels * 3.0 + 1.2)
   - Рельеф ArcticDEM 2м и гидрологическая модель паводка реки Обь (динамический уровень от 800 до 1050 см)
   - Спутниковая подложка Sentinel-2 (тайл T43VBN)
   - Связка бэкенда FastAPI с мобильным клиентом Flutter

5. **ТОП-10 КОНКРЕТНЫХ ДЕЙСТВИЙ С ПРИМЕРАМИ КОДА**:
   - Чёткие, внедряемые рекомендации.

Отвечай развёрнуто на русском языке, технические термины и код на английском/Python/Dart.

## ИСХОДНЫЙ КОД ДЛЯ АУДИТА:
"""

def main():
    print("=" * 60)
    print("City Pulse — Full Audit via Claude Opus 5 Thinking (TabiToken)")
    print("=" * 60)
    
    print("[1/3] Gathering codebase context...")
    context = build_context()
    print(f"Context length: {len(context):,} characters across {len(FILES_TO_AUDIT)} files.")
    
    full_prompt = AUDIT_PROMPT + "\n" + context
    
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": "You are the Principal Architect, Security Lead, and 3D Geospatial Expert."},
            {"role": "user", "content": full_prompt}
        ],
        "max_tokens": 16000,
        "temperature": 0.2
    }
    
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "User-Agent": "Antigravity/1.0",
        "X-Ident": IDENT,
        "Identification": IDENT,
    }
    
    print("[2/3] Sending request to Claude Opus 5 Thinking...")
    req = urllib.request.Request(BASE_URL, data=json.dumps(payload).encode("utf-8"), headers=headers)
    
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            content = data["choices"][0]["message"]["content"]
            usage = data.get("usage", {})
            print("[3/3] Audit received successfully!")
            print("Token Usage:", usage)
            
            output_file = PROJECT_ROOT / ".omc" / "plans" / "claude_opus_5_thinking_audit.md"
            output_file.parent.mkdir(parents=True, exist_ok=True)
            output_file.write_text(f"# City Pulse — Claude Opus 5 Thinking Full Audit\n\n{content}", encoding="utf-8")
            
            # Also write to brain artifact dir
            artifact_file = Path(r"C:\Users\рс\.gemini\antigravity\brain\196a6a60-78da-4074-9736-796b8601132e\claude_opus_5_thinking_audit.md")
            artifact_file.write_text(f"# City Pulse — Claude Opus 5 Thinking Full Audit\n\n{content}", encoding="utf-8")
            
            print(f"\nReport saved to:\n- {output_file}\n- {artifact_file}")
            print("\nPreview:")
            print(content[:1500])
    except Exception as e:
        print(f"Error calling Claude Opus 5 Thinking: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
