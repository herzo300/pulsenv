@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
echo ========================================
echo  Пульс Города - Единый мониторинг
echo  Telegram + VK + Firebase
echo ========================================
py start_all_monitoring.py
pause
