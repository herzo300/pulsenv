#!/usr/bin/env python3
"""
Обновление Firebase Realtime Database rules.
Нужно запустить один раз для настройки доступа.

Вариант 1: Через Firebase Console (рекомендуется)
Вариант 2: Через этот скрипт с ID token
"""

import os
import sys
import json
import webbrowser

PROJECT_ID = "soobshio"
RTDB_URL = f"https://{PROJECT_ID}-default-rtdb.europe-west1.firebasedatabase.app"

# Rules для Realtime Database
RULES = {
    "rules": {
        "complaints": {
            ".read": True,
            ".write": True,
            ".indexOn": ["created_at", "category", "status"],
        },
        "stats": {
            ".read": True,
            ".write": True,
        },
        # Всё остальное закрыто
        ".read": False,
        ".write": False,
    }
}


def main():
    print("=" * 60)
    print("🔥 Настройка Firebase Realtime Database Rules")
    print("=" * 60)
    print()
    print("Для работы real-time мониторинга нужно обновить rules.")
    print()
    print("Способ 1 (рекомендуется):")
    print(f"  1. Откройте: https://console.firebase.google.com/project/{PROJECT_ID}/database/rules")
    print("  2. Замените rules на:")
    print()
    print(json.dumps(RULES, indent=2, ensure_ascii=False))
    print()
    print("  3. Нажмите 'Publish'")
    print()

    answer = input("Открыть Firebase Console? (y/n): ").strip().lower()
    if answer == 'y':
        url = f"https://console.firebase.google.com/project/{PROJECT_ID}/database/{PROJECT_ID}-default-rtdb/rules"
        webbrowser.open(url)
        print(f"\n🌐 Открыто: {url}")

    print()
    print("После обновления rules, запустите тест:")
    print("  py test_vk_firebase.py")


if __name__ == "__main__":
    main()
