import os, httpx
key = os.getenv('OPENROUTER_API_KEY')
r = httpx.get('https://openrouter.ai/api/v1/auth/key',
    headers={'Authorization': 'Bearer '+key},
    proxy='socks5://172.18.0.2:9050', timeout=40)
print('auth/key status:', r.status_code)
print(r.text[:300])
