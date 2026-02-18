#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Запуск всех сервисов проекта
"""

import subprocess
import sys
import os
import time
from pathlib import Path

def run_service(name, script, cwd, delay=2):
    """Запуск сервиса в отдельном процессе"""
    print(f"\n[{name}] Запуск {script}...")
    env = os.environ.copy()
    env["PYTHONPATH"] = cwd + os.pathsep + env.get("PYTHONPATH", "")
    try:
        process = subprocess.Popen(
            [sys.executable, script],
            cwd=cwd,
            env=env,
            creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == 'win32' else 0
        )
        print(f"[{name}] Запущен (PID: {process.pid})")
        time.sleep(delay)
        return process
    except Exception as e:
        print(f"[{name}] Ошибка запуска: {e}")
        return None

def main():
    print("="*60)
    print("  ЗАПУСК ВСЕХ СЕРВИСОВ")
    print("="*60)
    
    # Корень проекта (scripts/maintenance -> scripts -> Soobshio_project)
    base_dir = Path(__file__).resolve().parent.parent.parent
    
    services = [
        ("Telegram Bot", "start_telegram_bot.py"),
        ("Monitoring", "start_all_monitoring.py"),
    ]
    
    processes = []
    
    for name, script in services:
        script_path = base_dir / script
        if script_path.exists():
            proc = run_service(name, str(script_path), str(base_dir))
            if proc:
                processes.append((name, proc))
        else:
            print(f"[{name}] Файл {script} не найден")
    
    print("\n" + "="*60)
    print("  СЕРВИСЫ ЗАПУЩЕНЫ")
    print("="*60)
    print(f"\nЗапущено процессов: {len(processes)}")
    for name, proc in processes:
        print(f"  - {name} (PID: {proc.pid})")
    
    print("\nДля остановки закройте окна или нажмите Ctrl+C")
    print("="*60)
    
    try:
        # Ждем завершения
        for name, proc in processes:
            proc.wait()
    except KeyboardInterrupt:
        print("\n\nОстановка сервисов...")
        for name, proc in processes:
            try:
                proc.terminate()
                print(f"[{name}] Остановлен")
            except:
                pass

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nПрервано пользователем")
        sys.exit(0)
    except Exception as e:
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
