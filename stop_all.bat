@echo off
chcp 65001 >nul
title Пульс города — Остановка
color 0C

echo ══════════════════════════════════════════════════
echo   ОСТАНОВКА ВСЕХ СЕРВИСОВ
echo ══════════════════════════════════════════════════
echo.

taskkill /F /IM python.exe >nul 2>&1

echo   ✅ Все Python процессы остановлены.
echo.
pause
