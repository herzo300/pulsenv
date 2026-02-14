@echo off
chcp 65001 >nul
REM test_browser.bat - Запуск тестирования в браузере для Windows

echo 🌐 Запуск браузерного тестирования СообщиО
echo ==========================================

echo.
echo 📋 Шаг 1: Проверка backend сервера...
curl -s http://localhost:8000/health >nul
if %errorlevel% == 0 (
    echo ✅ Backend запущен
) else (
    echo ⚠️  Backend не отвечает
    echo    Запустите в отдельном окне: python run_backend.py
    pause
)

echo.
echo 📋 Шаг 2: Запуск HTTP сервера...
cd /d "%~dp0web"

echo 🌐 Сервер запущен на http://localhost:8080
echo 📄 Тестовая страница: http://localhost:8080/test.html
echo 🏠 Главная страница: http://localhost:8080
echo.
echo 🚀 Открытие браузера...
start http://localhost:8080/test.html

echo ⛔ Для остановки закройте это окно
echo.
python -m http.server 8080
