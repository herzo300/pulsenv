#!/usr/bin/env python3
"""
Настройка VK API для мониторинга пабликов.
Запустите: py setup_vk.py
"""

import os
import sys
import webbrowser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

VK_TOKEN = os.getenv("VK_SERVICE_TOKEN", "")


def main():
    if VK_TOKEN:
        print(f"✅ VK_SERVICE_TOKEN уже задан ({VK_TOKEN[:20]}...)")
        print("   Проверяю работоспособность...")
        test_token()
        return

    print("=" * 60)
    print("🔵 Настройка VK API для мониторинга")
    print("=" * 60)
    print()
    print("Для мониторинга VK пабликов нужен сервисный ключ доступа.")
    print()
    print("Как получить:")
    print("1. Откройте https://dev.vk.com/")
    print("2. Войдите в аккаунт VK")
    print("3. Перейдите в 'Мои приложения' → 'Создать'")
    print("4. Тип: Standalone-приложение, название: PulsGoroda")
    print("5. В настройках приложения найдите 'Сервисный ключ доступа'")
    print("6. Скопируйте его")
    print()

    answer = input("Открыть dev.vk.com в браузере? (y/n): ").strip().lower()
    if answer == 'y':
        webbrowser.open("https://dev.vk.com/")

    token = input("\nВставьте сервисный ключ VK: ").strip()
    if not token:
        print("❌ Токен не введён")
        return

    # Добавляем в .env
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    with open(env_path, 'a', encoding='utf-8') as f:
        f.write(f"\n# VK API\nVK_SERVICE_TOKEN={token}\n")

    print(f"✅ VK_SERVICE_TOKEN добавлен в .env")
    print("   Перезапустите мониторинг для применения.")


def test_token():
    import httpx
    try:
        r = httpx.get("https://api.vk.com/method/wall.get", params={
            "owner_id": -67104825,  # Подслушано Нижневартовск
            "count": 1,
            "access_token": VK_TOKEN,
            "v": "5.199",
        }, timeout=10)
        data = r.json()
        if "error" in data:
            print(f"❌ VK API error: {data['error'].get('error_msg', 'unknown')}")
        elif "response" in data:
            count = data["response"].get("count", 0)
            print(f"✅ VK API работает! Постов в тестовой группе: {count}")
            if data["response"].get("items"):
                post = data["response"]["items"][0]
                print(f"   Последний пост: {post.get('text', '')[:80]}...")
        else:
            print(f"⚠️ Неожиданный ответ: {str(data)[:200]}")
    except Exception as e:
        print(f"❌ Ошибка: {e}")


if __name__ == "__main__":
    main()
