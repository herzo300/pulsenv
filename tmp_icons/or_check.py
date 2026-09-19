import os, httpx
key = os.getenv('OPENROUTER_API_KEY')
print('key len:', len(key))
for model in ['z-ai/glm-5.2', 'anthropic/claude-sonnet-4.5', 'google/gemini-2.5-pro']:
    try:
        r = httpx.post('https://openrouter.ai/api/v1/chat/completions',
            headers={'Authorization': 'Bearer '+key, 'Content-Type':'application/json'},
            json={'model':model,'messages':[{'role':'user','content':'Reply exactly: OK'}],'max_tokens':10},
            proxy='socks5://172.18.0.2:9050', timeout=45)
        print(model, r.status_code, r.json()['choices'][0]['message']['content'][:20] if r.status_code==200 else r.text[:80])
    except Exception as e:
        print(model, 'ERR', str(e)[:60])
