import httpx, os, json, base64
from dotenv import load_dotenv
load_dotenv()
key = os.getenv('ZAI_API_KEY','')
BASE = 'https://api.z.ai/api/paas/v4'

# 1. Text analysis test
print("=== TEXT: glm-4.7-flash ===")
r = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.7-flash',
        'messages': [{'role':'user','content':
            'Analyze this complaint about a city problem in Nizhnevartovsk. '
            'Return JSON with category, address, summary. '
            'Text: Na ulice Mira 62 ne rabotaet ulichnoe osveschenie, fonari ne goryat 3 dnya. '
            'Categories: roads, lighting, housing, transport, ecology, snow, heating, water, garbage. '
            'Reply ONLY JSON: {"category":"...","address":"...","summary":"..."}'}],
        'max_tokens': 150
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=30.0)
print(f"Status: {r.status_code}")
if r.status_code == 200:
    d = r.json()
    content = d['choices'][0]['message']['content']
    print(f"Response: {content}")
    usage = d.get('usage',{})
    print(f"Tokens: {usage.get('prompt_tokens')}/{usage.get('completion_tokens')}")

# 2. Text analysis - Russian complaint
print("\n=== TEXT: Russian complaint ===")
complaint = "Na ulice Lenina 15 bolshaya yama na doroge, glubina 30 sm, opasno dlya mashin"
r2 = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.7-flash',
        'messages': [{'role':'user','content':
            f'Classify this city complaint. Categories: roads, lighting, housing, transport, ecology. '
            f'Text: {complaint}. Reply JSON only: {{"category":"...","address":"...","summary":"..."}}'}],
        'max_tokens': 100
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=30.0)
if r2.status_code == 200:
    print(f"Response: {r2.json()['choices'][0]['message']['content']}")

# 3. Vision test with glm-4.6v-flash
print("\n=== VISION: glm-4.6v-flash ===")
# Use a test image URL
r3 = httpx.post(f'{BASE}/chat/completions',
    json={
        'model': 'glm-4.6v-flash',
        'messages': [{
            'role': 'user',
            'content': [
                {'type': 'text', 'text': 'Describe what you see in this image in 2 sentences. Reply in English.'},
                {'type': 'image_url', 'image_url': {'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png'}}
            ]
        }],
        'max_tokens': 100
    },
    headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
    timeout=30.0)
print(f"Status: {r3.status_code}")
if r3.status_code == 200:
    print(f"Response: {r3.json()['choices'][0]['message']['content']}")
else:
    print(f"Error: {r3.text[:300]}")
