import httpx, os, json
from dotenv import load_dotenv
load_dotenv()
key = os.getenv('ZAI_API_KEY','')
BASE = 'https://api.z.ai/api/paas/v4'

for m in ['glm-4.7-flash','glm-4.5-flash','glm-4.6v-flash']:
    print(f'\n--- {m} ---')
    try:
        r = httpx.post(f'{BASE}/chat/completions',
            json={'model':m,'messages':[{'role':'user','content':'Скажи привет по-русски, одно слово'}],'max_tokens':20},
            headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'},
            timeout=30.0)
        if r.status_code == 200:
            d = r.json()
            text = d['choices'][0]['message']['content']
            usage = d.get('usage',{})
            pt = usage.get('prompt_tokens','?')
            ct = usage.get('completion_tokens','?')
            print(f'OK! Response: {text}')
            print(f'Tokens: prompt={pt}, completion={ct}')
        else:
            print(f'Error: {r.status_code} {r.text[:200]}')
    except Exception as e:
        print(f'Error: {e}')
