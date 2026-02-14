import httpx, os, json
from dotenv import load_dotenv
load_dotenv()
key = os.getenv('ZAI_API_KEY','')
BASE = 'https://api.z.ai/api/paas/v4'

results = {}

# 1. Text - complaint analysis
r = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.7-flash',
        'messages': [
            {'role':'system','content':'You are a city problem analyst for Nizhnevartovsk, Russia. Always reply in valid JSON.'},
            {'role':'user','content':
            'Analyze complaint: "Na ulice Mira 62 ne rabotaet ulichnoe osveschenie, fonari ne goryat 3 dnya, ves dvor v temnote"\n'
            'Categories: roads, lighting, housing, transport, ecology, snow, heating, water, garbage, other\n'
            'Return JSON: {"category":"...","address":"...","summary":"..."}'}
        ],
        'max_tokens': 150
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=30.0)
results['text_test_1'] = {'status': r.status_code, 'body': r.json() if r.status_code==200 else r.text[:300]}

# 2. Russian text
r2 = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.7-flash',
        'messages': [
            {'role':'system','content':'Ты аналитик городских проблем Нижневартовска. Отвечай только JSON.'},
            {'role':'user','content':
            'Проанализируй жалобу: "На улице Ленина 15 большая яма на дороге, глубина 30 см, опасно для машин"\n'
            'Категории: ЖКХ, Дороги, Освещение, Транспорт, Экология, Снег/Наледь, Отопление, Водоснабжение, Мусор, Прочее\n'
            'Верни JSON: {"category":"...","address":"...","summary":"..."}'}
        ],
        'max_tokens': 200
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=30.0)
results['text_test_2_ru'] = {'status': r2.status_code, 'body': r2.json() if r2.status_code==200 else r2.text[:300]}

# 3. Vision test
r3 = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.6v-flash',
        'messages': [{
            'role': 'user',
            'content': [
                {'type': 'text', 'text': 'What do you see? Reply in English, 1 sentence.'},
                {'type': 'image_url', 'image_url': {'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png'}}
            ]
        }],
        'max_tokens': 50
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=30.0)
results['vision_test'] = {'status': r3.status_code, 'body': r3.json() if r3.status_code==200 else r3.text[:300]}

# Save results
with open('zai_test_results.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print("Results saved to zai_test_results.json")
