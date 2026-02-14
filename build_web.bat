@echo off
chcp 65001 >nul
REM build_web.bat - Скрипт сборки Flutter Web для Windows

echo 🚀 Сборка СообщиО Web...
echo ================================

REM Проверка Flutter
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter не найден. Установите Flutter SDK
    pause
    exit /b 1
)

cd /d "%~dp0lib"

echo 📦 Очистка предыдущей сборки...
flutter clean

echo 📥 Установка зависимостей...
flutter pub get

echo 🔧 Проверка конфигурации...
flutter doctor -v

echo 🌐 Сборка Web (release)...
flutter build web --release --web-renderer html

echo.
echo ✅ Сборка завершена!
echo.
echo 📁 Файлы сборки: lib\build\web\
echo.
echo 🚀 Варианты деплоя:
echo   1. GitHub Pages: скопируйте содержимое lib\build\web\ в gh-pages
echo   2. Firebase: firebase deploy --only hosting
echo   3. Локально: cd lib\build\web ^&^& python -m http.server 8080
echo.
echo 📱 Для Telegram Mini App:
echo   - URL должен быть HTTPS
echo   - Укажите URL в @BotFather
echo.
pause
