#!/bin/bash
# test_browser.sh - Запуск тестирования в браузере

echo "🌐 Запуск браузерного тестирования СообщиО"
echo "=========================================="

# Проверяем, запущен ли backend
echo ""
echo "📋 Шаг 1: Проверка backend сервера..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Backend запущен"
else
    echo "⚠️  Backend не отвечает. Запустите: python run_backend.py"
    echo ""
    read -p "Запустить backend автоматически? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Запуск backend..."
        python run_backend.py &
        BACKEND_PID=$!
        sleep 3
    fi
fi

# Запускаем HTTP сервер для web директории
echo ""
echo "📋 Шаг 2: Запуск HTTP сервера..."
cd "$(dirname "$0")/web"

echo "🌐 Сервер запущен на http://localhost:8080"
echo "📄 Тестовая страница: http://localhost:8080/test.html"
echo "🏠 Главная страница: http://localhost:8080"
echo ""
echo "⛔ Нажмите Ctrl+C для остановки"
echo ""

python3 -m http.server 8080
