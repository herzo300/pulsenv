# Деплой Cloudflare Worker (PowerShell)
# Требуется: npm install -g wrangler
# Авторизация: wrangler login

$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "🔨 Сборка worker..." -ForegroundColor Cyan
python build_worker.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Ошибка сборки!" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Деплой worker..." -ForegroundColor Cyan
wrangler deploy
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Ошибка деплоя! Убедитесь что:" -ForegroundColor Red
    Write-Host "   1. wrangler установлен: npm install -g wrangler" -ForegroundColor Yellow
    Write-Host "   2. Вы авторизованы: wrangler login" -ForegroundColor Yellow
    Write-Host "   3. У вас есть доступ к аккаунту Cloudflare" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Деплой завершен!" -ForegroundColor Green
Write-Host "   URL: https://anthropic-proxy.uiredepositionherzo.workers.dev" -ForegroundColor Cyan
