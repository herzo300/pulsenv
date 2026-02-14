import httpx, os, json, time, base64
from dotenv import load_dotenv
load_dotenv()
key = os.getenv('ZAI_API_KEY','')
BASE = 'https://api.z.ai/api/paas/v4'

results = {}

# 1. Text with 1024 tokens to let reasoning finish
print("Test 1: glm-4.7-flash (1024 tokens)...")
r = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.7-flash',
        'messages': [
            {'role':'system','content':'You are a city problem analyst. Reply ONLY with valid JSON, no explanation.'},
            {'role':'user','content':
            'Classify: "Na ulice Mira 62 ne rabotaet ulichnoe osveschenie, fonari ne goryat 3 dnya"\n'
            'Categories: roads, lighting, housing, transport, ecology\n'
            'JSON: {"category":"...","address":"...","summary":"..."}'}
        ],
        'max_tokens': 1024
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=60.0)
d = r.json()
content = d.get('choices',[{}])[0].get('message',{}).get('content','')
reasoning = d.get('choices',[{}])[0].get('message',{}).get('reasoning_content','')
results['text_1'] = {
    'status': r.status_code,
    'content': content,
    'reasoning_len': len(reasoning),
    'finish_reason': d.get('choices',[{}])[0].get('finish_reason',''),
    'tokens': d.get('usage',{})
}

# 2. glm-4.5-flash with 1024 tokens
print("Test 2: glm-4.5-flash (1024 tokens)...")
r2 = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.5-flash',
        'messages': [
            {'role':'system','content':'Ты аналитик городских проблем. Отвечай ТОЛЬКО JSON.'},
            {'role':'user','content':
            'Жалоба: "На улице Ленина 15 большая яма на дороге, глубина 30 см, опасно для машин"\n'
            'Категории: ЖКХ, Дороги, Освещение, Транспорт, Экология, Снег, Отопление, Вода, Мусор, Прочее\n'
            'JSON: {"category":"...","address":"...","summary":"..."}'}
        ],
        'max_tokens': 1024
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=60.0)
d2 = r2.json()
content2 = d2.get('choices',[{}])[0].get('message',{}).get('content','')
results['text_2'] = {
    'status': r2.status_code,
    'content': content2,
    'finish_reason': d2.get('choices',[{}])[0].get('finish_reason',''),
    'tokens': d2.get('usage',{})
}

# 3. Vision - download image first, send as base64
print("Test 3: glm-4.6v-flash vision (base64)...")
# Download a small test image
img_r = httpx.get('https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg', timeout=10)
if img_r.status_code == 200:
    img_b64 = base64.b64encode(img_r.content).decode('utf-8')
    for attempt in range(3):
        r3 = httpx.post(f'{BASE}/chat/completions',
            json={
                'model': 'glm-4.6v-flash',
                'messages': [{
                    'role': 'user',
                    'content': [
                        {'type': 'text', 'text': 'What is in this image? Reply in English, 1 sentence.'},
                        {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{img_b64}'}}
                    ]
                }],
                'max_tokens': 200
            },
            headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
            timeout=30.0)
        if r3.status_code == 200:
            d3 = r3.json()
            results['vision'] = {
                'status': 200,
                'content': d3.get('choices',[{}])[0].get('message',{}).get('content',''),
                'tokens': d3.get('usage',{})
            }
            break
        else:
            print(f"  Attempt {attempt+1}: {r3.status_code} {r3.text[:100]}")
            time.sleep(3)
    else:
        results['vision'] = {'error': r3.text[:300]}

with open('zai_test_v3.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print("Done! Results in zai_test_v3.json")
