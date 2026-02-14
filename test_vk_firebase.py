#!/usr/bin/env python3
"""
Тест VK мониторинга и Firebase интеграции.
py test_vk_firebase.py
"""

import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()


async def test_vk_filters():
    """Тест фильтров VK"""
    from services.vk_monitor_service import is_vk_ad, has_vk_complaint_markers, is_vk_relevant

    print("=" * 50)
    print("🔵 Тест VK фильтров")
    print("=" * 50)

    # Реклама
    ads = [
        "Купи промокод скидка 50% на все товары!",
        "Розыгрыш iPhone! Подписывайтесь на канал!",
        "Казино онлайн, ставки на спорт",
        "Продаётся квартира 2к, ул. Мира 15",
        "Вакансия: требуется сотрудник в магазин",
    ]
    print("\n🚫 Реклама (должно быть True):")
    for text in ads:
        result = is_vk_ad(text)
        status = "✅" if result else "❌"
        print(f"  {status} {result}: {text[:50]}")

    # Жалобы
    complaints = [
        "Огромная яма на дороге по ул. Мира 62, невозможно проехать",
        "Не работает освещение во дворе дома Ленина 15",
        "Прорыв трубы на ул. Чапаева, затопило подвал",
        "Мусор не вывозят уже неделю, контейнеры переполнены",
        "ДТП на перекрёстке Мира и Ленина, пробка",
        "Лифт не работает 3 дня, дом Интернациональная 20",
    ]
    print("\n✅ Жалобы (должно быть True):")
    for text in complaints:
        result = has_vk_complaint_markers(text)
        status = "✅" if result else "❌"
        print(f"  {status} {result}: {text[:50]}")

    # Нерелевантное
    irrelevant = [
        "Привет",
        "Ок",
        "Погода сегодня хорошая в Нижневартовске",
    ]
    print("\n⏭️ Нерелевантное (должно быть False):")
    for text in irrelevant:
        result = is_vk_relevant(text, "Прочее")
        status = "✅" if not result else "❌"
        print(f"  {status} {result}: {text[:50]}")

    print()


async def test_vk_api():
    """Тест VK API"""
    from services.vk_monitor_service import VK_SERVICE_TOKEN, resolve_groups

    print("=" * 50)
    print("🔵 Тест VK API")
    print("=" * 50)

    if not VK_SERVICE_TOKEN:
        print("⚠️ VK_SERVICE_TOKEN не задан в .env")
        print("   Запустите: py setup_vk.py")
        return False

    print(f"Token: {VK_SERVICE_TOKEN[:20]}...")
    groups = await resolve_groups()
    if groups:
        print(f"✅ Резолвлено {len(groups)} групп")
        for sn, gid, name in groups:
            print(f"   • {name} (id: {gid})")
        return True
    else:
        print("❌ Не удалось резолвить группы")
        return False


async def test_firebase():
    """Тест Firebase"""
    from services.firebase_service import get_firestore, push_complaint

    print("=" * 50)
    print("🔥 Тест Firebase")
    print("=" * 50)

    db = get_firestore()
    if not db:
        print("⚠️ Firebase не настроен")
        print("   Запустите: py setup_firebase.py")
        return False

    print("✅ Firestore client подключён")

    # Тестовая запись
    doc_id = await push_complaint({
        "category": "Тест",
        "summary": "Тестовая жалоба из test_vk_firebase.py",
        "text": "Это тестовое сообщение для проверки Firebase интеграции",
        "address": "ул. Мира 1, Нижневартовск",
        "source": "test",
        "source_name": "Тест",
        "post_link": "",
    })

    if doc_id:
        print(f"✅ Тестовая запись создана: {doc_id}")
        return True
    else:
        print("❌ Не удалось записать в Firestore")
        return False


async def main():
    await test_vk_filters()
    print()
    vk_ok = await test_vk_api()
    print()
    fb_ok = await test_firebase()

    print("\n" + "=" * 50)
    print("📊 Результат:")
    print(f"   VK API: {'✅' if vk_ok else '⚠️ нужен VK_SERVICE_TOKEN'}")
    print(f"   Firebase: {'✅' if fb_ok else '⚠️ нужен service account'}")
    print("=" * 50)


if __name__ == "__main__":
    asyncio.run(main())
