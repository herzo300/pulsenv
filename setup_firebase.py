#!/usr/bin/env python3
"""
Генерация Firebase service account key через Google Cloud API.
Запустите: py setup_firebase.py
"""

import json
import os
import sys
import webbrowser

PROJECT_ID = "soobshio"
KEY_FILE = "firebase-service-account.json"

def main():
    if os.path.exists(KEY_FILE):
        print(f"✅ {KEY_FILE} уже существует")
        with open(KEY_FILE) as f:
            data = json.load(f)
        print(f"   Project: {data.get('project_id')}")
        print(f"   Client email: {data.get('client_email')}")
        return

    print("=" * 60)
    print("🔥 Настройка Firebase Service Account")
    print("=" * 60)
    print()
    print("Для работы Firebase Admin SDK нужен service account key.")
    print("Скачайте его из Firebase Console:")
    print()
    print(f"1. Откройте: https://console.firebase.google.com/project/{PROJECT_ID}/settings/serviceaccounts/adminsdk")
    print("2. Нажмите 'Generate new private key'")
    print("3. Сохраните файл как: firebase-service-account.json")
    print(f"   в папку: {os.path.abspath('.')}")
    print()

    answer = input("Открыть Firebase Console в браузере? (y/n): ").strip().lower()
    if answer == 'y':
        url = f"https://console.firebase.google.com/project/{PROJECT_ID}/settings/serviceaccounts/adminsdk"
        webbrowser.open(url)
        print(f"\n🌐 Открыто: {url}")
        print(f"\nПосле скачивания переименуйте файл в '{KEY_FILE}' и положите в корень проекта.")

    # Проверяем ещё раз
    input("\nНажмите Enter после сохранения файла...")
    if os.path.exists(KEY_FILE):
        print(f"✅ {KEY_FILE} найден!")
        with open(KEY_FILE) as f:
            data = json.load(f)
        print(f"   Project: {data.get('project_id')}")
        print(f"   Client email: {data.get('client_email')}")
    else:
        print(f"❌ {KEY_FILE} не найден. Положите файл в корень проекта и перезапустите.")


if __name__ == "__main__":
    main()
