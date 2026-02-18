#!/bin/bash
# Деплой Cloudflare Worker
# Требуется: npm install -g wrangler
# Авторизация: wrangler login

cd "$(dirname "$0")"

echo "🔨 Сборка worker..."
python3 build_worker.py || python build_worker.py

echo "🚀 Деплой worker..."
wrangler deploy

echo "✅ Деплой завершен!"
echo "   URL: https://anthropic-proxy.uiredepositionherzo.workers.dev"
