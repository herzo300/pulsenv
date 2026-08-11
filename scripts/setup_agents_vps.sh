#!/bin/bash
echo "Установка OpenWorker и Agent-Reach для City Pulse"

cd /path/to/project/services/Backend

echo "=== 1. Настройка OpenWorker ==="
cd openworker
# Создаем виртуальное окружение, если необходимо, или устанавливаем в системный python
pip install -r requirements.txt || pip install aisuite openai anthropic google-genai textual fastapi uvicorn pydantic mcp httpx websockets ddgs croniter pypdf pypdfium2 tomli
cd ..

echo "=== 2. Настройка Agent-Reach ==="
cd agent_reach
pip install -r requirements.txt || pip install -e .
cd ..

echo "✅ Установка завершена. Вы можете запустить бэкенд FastAPI."
