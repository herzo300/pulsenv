#!/usr/bin/env python3
"""Остановить предыдущий экземпляр бота (по lock-файлу). Решает TelegramConflictError."""
import os
import sys
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def main():
    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    lock_path = os.path.join(base, "data", "telegram_bot.lock")
    if not os.path.exists(lock_path):
        print("Lock-файл не найден — бот не запущен.")
        return 0

    try:
        with open(lock_path, "r") as f:
            pid = int(f.read().strip())
    except (ValueError, OSError):
        os.remove(lock_path)
        print("Lock повреждён, удалён.")
        return 0

    try:
        if sys.platform == "win32":
            subprocess.run(["taskkill", "/F", "/PID", str(pid)], check=False, capture_output=True)
        else:
            os.kill(pid, 9)
        print(f"Процесс {pid} остановлен.")
    except Exception as e:
        print(f"Не удалось остановить {pid}: {e}")

    try:
        os.remove(lock_path)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
