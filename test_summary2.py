import asyncio, sys, os
sys.path.insert(0, '.')
from dotenv import load_dotenv
load_dotenv()
from services.zai_service import analyze_complaint

async def main():
    text = "Сегодня утром на ул. Мира 62 прорвало трубу горячего водоснабжения. Вода хлещет уже 3 часа, затопило подвал и парковку. Жители дома звонили в аварийку, но никто не приехал. Температура на улице минус 30, вода замерзает и образуется наледь на тротуаре."
    r = await analyze_complaint(text)
    print(f"Provider: {r.get('provider')}")
    print(f"Category: {r.get('category')}")
    print(f"Address: {r.get('address')}")
    print(f"Relevant: {r.get('relevant')}")
    print(f"SUMMARY: {r.get('summary')}")
    print(f"Original: {text[:60]}...")

asyncio.run(main())
