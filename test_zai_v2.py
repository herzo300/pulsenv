import httpx, os, json, time
from dotenv import load_dotenv
load_dotenv()
key = os.getenv('ZAI_API_KEY','')
BASE = 'https://api.z.ai/api/paas/v4'

results = {}

# 1. Text with higher max_tokens (reasoning uses tokens)
print("Test 1: glm-4.7-flash text analysis...")
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
        'max_tokens': 512
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=60.0)
results['text_1'] = r.json() if r.status_code==200 else {'error': r.text[:300]}

# 2. Try glm-4.5-flash (may not have reasoning overhead)
print("Test 2: glm-4.5-flash text analysis...")
r2 = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.5-flash',
        'messages': [
            {'role':'system','content':'You are a city problem analyst. Reply ONLY with valid JSON.'},
            {'role':'user','content':
            'Classify complaint: "Na ulice Lenina 15 bolshaya yama na doroge, glubina 30 sm"\n'
            'Categories: roads, lighting, housing, transport, ecology\n'
            'JSON: {"category":"...","address":"...","summary":"..."}'}
        ],
        'max_tokens': 200
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=60.0)
results['text_2'] = r2.json() if r2.status_code==200 else {'error': r2.text[:300]}

# 3. Vision with retry
print("Test 3: glm-4.6v-flash vision...")
for attempt in range(3):
    r3 = httpx.post(f'{BASE}/chat/completions',
        json={
            'model': 'glm-4.6v-flash',
            'messages': [{
                'role': 'user',
                'content': [
                    {'type': 'text', 'text': 'What is in this image? Reply in English, 1 sentence.'},
                    {'type': 'image_url', 'image_url': {'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png'}}
                ]
            }],
            'max_tokens': 100
        },
        headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
        timeout=30.0)
    if r3.status_code == 200:
        results['vision'] = r3.json()
        break
    else:
        print(f"  Attempt {attempt+1}: {r3.status_code} - retrying...")
        time.sleep(3)
else:
    results['vision'] = {'error': r3.text[:300]}

# Save
with open('zai_test_v2.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)
print("Done! Results in zai_test_v2.json")
