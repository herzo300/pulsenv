#!/usr/bin/env python3
"""Тест: AI генерирует краткий анализ, а не копию текста"""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv()
from services.zai_service import analyze_complaint

TEXTS = [
    "Сегодня утром на ул. Мира 62 прорвало трубу горячего водоснабжения. Вода хлещет уже 3 часа, затопило подвал и парковку. Жители дома звонили в аварийку, но никто не приехал. Температура на улице минус 30, вода замерзает и образуется наледь на тротуаре. Просим срочно принять меры!",
    "На перекрёстке Мира и Интернациональной уже третий день не работает светофор. Пешеходы перебегают дорогу как попало, вчера чуть не сбили ребёнка. ГИБДД в курсе, но ничего не делают.",
    "Во дворе дома по ул. Ленина 15 огромная яма, в которую вчера провалилась машина. Яму никто не огородил, ночью её не видно. Дети играют рядом.",
]

async def main():
    for i, t in enumerate(TEXTS, 1):
        r = await analyze_complaint(t)
        print(f"--- Тест {i} [{r.get('provider')}] ---")
        print(f"  Категория: {r.get('category')}")
        print(f"  Адрес: {r.get('address')}")
        print(f"  СУТЬ: {r.get('summary')}")
        print(f"  Оригинал: {t[:60]}...")
        print()

asyncio.run(main())
