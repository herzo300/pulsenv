#!/bin/bash
# build_web.sh - Скрипт сборки Flutter Web с поддержкой Telegram Mini App

echo "🚀 Сборка СообщиО Web..."
echo "================================"

# Проверка Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не найден. Установите Flutter SDK"
    exit 1
fi

cd "$(dirname "$0")/lib"

echo "📦 Очистка предыдущей сборки..."
flutter clean

echo "📥 Установка зависимостей..."
flutter pub get

echo "🔧 Проверка конфигурации..."
flutter doctor -v

echo "🌐 Сборка Web (release)..."
flutter build web --release \
    --web-renderer html \
    --csp \
    --pwa-strategy offline-first

echo ""
echo "✅ Сборка завершена!"
echo ""
echo "📁 Файлы сборки: lib/build/web/"
echo ""
echo "🚀 Деплой:"
echo "  1. GitHub Pages: gh-pages -d lib/build/web"
echo "  2. Firebase: firebase deploy --only hosting"
echo "  3. VPS: scp -r lib/build/web/* user@server:/var/www/html/"
echo ""
echo "📱 Для Telegram Mini App:"
echo "  - Укажите URL в @BotFather"
echo "  - URL должен быть HTTPS"
echo ""
