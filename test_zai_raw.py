import asyncio, os, sys, httpx, json
sys.path.insert(0, '.')
from dotenv import load_dotenv
load_dotenv()

key = os.getenv('ZAI_API_KEY', '')

async def main():
    async with httpx.AsyncClient(timeout=60) as c:
        r = await c.post('https://api.z.ai/api/paas/v4/chat/completions',
            json={
                'model': 'glm-4.7-flash',
                'messages': [{'role': 'user', 'content': 'Reply ONLY with JSON: {"test":true}'}],
                'max_tokens': 4096
            },
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'})
        print(f'Status: {r.status_code}')
        if r.status_code == 200:
            d = r.json()
            msg = d['choices'][0]['message']
            print(f'Keys: {list(msg.keys())}')
            print(f'Content: [{msg.get("content", "")}]')
            rc = msg.get('reasoning_content', '')
            if rc:
                print(f'Reasoning (first 300): [{rc[:300]}]')
        else:
            print(f'Error: {r.text[:300]}')

asyncio.run(main())
