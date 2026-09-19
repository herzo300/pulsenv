import os
import httpx

key = os.getenv('OPENROUTER_API_KEY')
print('key len:', len(key))
try:
    r = httpx.get(
        'https://openrouter.ai/api/v1/auth/key',
        headers={'Authorization': 'Bearer ' + key},
        proxy='socks5://172.18.0.2:9050',
        timeout=40,
    )
    print('auth/key status:', r.status_code)
    print(r.text[:300])
except Exception as e:
    print('ERR', str(e)[:100])
