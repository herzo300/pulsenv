import os, httpx
token = os.getenv('TG_BOT_TOKEN','').strip('"')
r = httpx.get(f'https://api.telegram.org/bot{token}/getMe', proxy='socks5://172.18.0.2:9050', timeout=40)
print(r.json())
