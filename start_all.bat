@echo off
chcp 65001 >nul
title Пульс города Нижневартовск — Все сервисы
color 0A

echo ══════════════════════════════════════════════════
echo   ПУЛЬС ГОРОДА НИЖНЕВАРТОВСК — ЗАПУСК СЕРВИСОВ
echo ══════════════════════════════════════════════════
echo.

:: Переходим в папку скрипта
pushd "%~dp0"

:: Убиваем старые процессы Python (если есть)
echo [1/5] Останавливаю старые процессы...
taskkill /F /IM python.exe >nul 2>&1
timeout /t 2 /nobreak >nul

:: Проверяем сессию Telethon
echo [2/5] Проверяю сессию Telethon...
if not exist "monitoring_session.session" (
    echo.
    echo ╔══════════════════════════════════════════════╗
    echo ║  ВНИМАНИЕ: Сессия мониторинга не найдена!   ║
    echo ║  Запускаю авторизацию Telethon...            ║
    echo ║  Введите код из Telegram когда попросят.     ║
    echo ╚══════════════════════════════════════════════╝
    echo.
    py auth_telethon.py
    if errorlevel 1 (
        echo ОШИБКА авторизации Telethon!
        pause
        exit /b 1
    )
    echo.
)

:: Запускаем бота
echo [3/5] Запускаю Telegram бота @pulsenvbot...
start "PulseNV Bot" /min py start_telegram_bot.py
timeout /t 3 /nobreak >nul
echo       ✓ Бот запущен

:: Запускаем мониторинг TG + VK
echo [4/5] Запускаю мониторинг (Telegram + VK)...
start "PulseNV Monitor" /min py start_all_monitoring.py
timeout /t 3 /nobreak >nul
echo       ✓ Мониторинг запущен

:: Статус
echo [5/5] Проверяю процессы...
timeout /t 2 /nobreak >nul

echo.
echo ══════════════════════════════════════════════════
echo   ✅ ВСЕ СЕРВИСЫ ЗАПУЩЕНЫ
echo ══════════════════════════════════════════════════
echo.
echo   🤖 Бот:        @pulsenvbot (polling)
echo   📡 Мониторинг: 8 TG каналов + 8 VK пабликов
echo   🗄️  База:       soobshio.db (SQLite)
echo   🔥 Firebase:   real-time sync
echo   🌐 Worker:     anthropic-proxy...workers.dev
echo.
echo   Окна свёрнуты в панель задач.
echo   Для остановки: stop_all.bat или закройте окна.
echo.
echo ══════════════════════════════════════════════════

popd
pause
