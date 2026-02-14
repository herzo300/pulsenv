#!/usr/bin/env python3
"""Тест: определение УК по адресу и координатам"""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from services.uk_service import find_uk_by_address, find_uk_by_coords, get_all_uk_emails


async def main():
    print("=" * 60)
    print("ТЕСТ ОПРЕДЕЛЕНИЯ УПРАВЛЯЮЩЕЙ КОМПАНИИ")
    print("=" * 60)

    # Тест 1: По адресу
    tests = [
        "ул. Мира, д. 10",
        "ул. Мира, 36",
        "ул. Нефтяников, 44",
        "ул. Чапаева, 49",
        "ул. 60 лет Октября, 27",
        "проспект Победы, 1",
        "ул. Интернациональная, 7",
        "ул. Дружбы Народов, 25",
    ]

    print("\n--- Тест 1: Поиск УК по адресу ---")
    for addr in tests:
        uk = find_uk_by_address(addr)
        if uk:
            print(f"✅ {addr}")
            print(f"   🏢 {uk['name']}")
            print(f"   📧 {uk.get('email', '-')}")
            print(f"   📞 {uk.get('phone', '-')}")
            print(f"   👤 {uk.get('director', '-')}")
        else:
            print(f"❌ {addr} — УК не найдена")
        print()

    # Тест 2: По координатам (ул. Мира, 10 — Нижневартовск)
    print("--- Тест 2: Поиск УК по координатам ---")
    coords_tests = [
        (60.9380, 76.5968, "ул. Мира ~10"),
        (60.9344, 76.5531, "центр города"),
    ]
    for lat, lon, desc in coords_tests:
        uk = await find_uk_by_coords(lat, lon)
        if uk:
            print(f"✅ {lat:.4f}, {lon:.4f} ({desc})")
            print(f"   🏢 {uk['name']}")
            print(f"   📧 {uk.get('email', '-')}")
            print(f"   📍 Геокод: {uk.get('geocoded_address', '-')}")
        else:
            print(f"❌ {lat:.4f}, {lon:.4f} ({desc}) — УК не найдена")
        print()

    # Тест 3: Все email УК
    print("--- Тест 3: Все email УК ---")
    emails = get_all_uk_emails()
    print(f"📧 Всего УК с email: {len(emails)}")
    for e in emails[:10]:
        print(f"   🏢 {e['name']}: {e['email']} ({e['houses']} домов)")

    print(f"\n✅ Тесты завершены")


asyncio.run(main())
