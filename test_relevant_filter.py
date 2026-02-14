#!/usr/bin/env python3
"""Тест: AI фильтрация relevant + geoparse"""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()

from services.zai_service import analyze_complaint
from services.geo_service import geoparse

TESTS = [
    # Должно быть relevant=True
    ("На ул. Мира 62 прорвало трубу, вода заливает подвал уже 3 часа", True),
    ("Во дворе дома по ул. Ленина 15 не убирают снег уже неделю, дети падают", True),
    ("На перекрёстке Мира и Интернациональной не работает светофор третий день", True),
    # Должно быть relevant=False
    ("Продаётся квартира 2-комнатная, район 10П, цена 3.5 млн, звоните!", False),
    ("Розыгрыш iPhone 15! Подпишись и поставь лайк, победитель 1 марта", False),
    ("Гороскоп на сегодня: Овнам повезёт в любви, Тельцам стоит быть осторожнее", False),
]

async def main():
    print("=" * 60)
    print("ТЕСТ AI ФИЛЬТРАЦИИ + ГЕОПАРСИНГ")
    print("=" * 60)
    
    passed = 0
    for text, expected_relevant in TESTS:
        result = await analyze_complaint(text)
        relevant = result.get("relevant", True)
        provider = result.get("provider", "?")
        category = result.get("category", "?")
        address = result.get("address")
        location_hints = result.get("location_hints")
        
        # Геопарсинг
        geo = await geoparse(text, ai_address=address, location_hints=location_hints)
        
        status = "✅" if relevant == expected_relevant else "❌"
        if relevant == expected_relevant:
            passed += 1
        
        print(f"\n{status} [{provider}] relevant={relevant} (ожидалось {expected_relevant})")
        print(f"   Текст: {text[:60]}...")
        print(f"   Категория: {category}, Адрес: {address}")
        print(f"   Гео: {geo.get('address')} ({geo.get('lat')}, {geo.get('lng')}) [{geo.get('geo_source')}]")
    
    print(f"\n{'=' * 60}")
    print(f"Результат: {passed}/{len(TESTS)} тестов пройдено")
    print(f"{'=' * 60}")

asyncio.run(main())
