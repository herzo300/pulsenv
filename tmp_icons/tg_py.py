import os, httpx, json
token = os.getenv('TG_BOT_TOKEN','').strip('"')
print('token_len:', len(token))
for proxy in ['socks5://tor:9050', None]:
    try:
        with httpx.Client(proxy=proxy, timeout=25) as c:
            r = c.get(f'https://api.telegram.org/bot{token}/getMe')
            print(('tor' if proxy else 'direct'), r.status_code, r.text[:120])
            if r.status_code == 200:
                r2 = c.get(f'https://api.telegram.org/bot{token}/getUpdates?limit=10')
                chats = {}
                for u in r2.json().get('result', []):
                    m = u.get('message') or u.get('edited_message') or {}
                    ch = m.get('chat', {})
                    if ch.get('id'): chats[ch['id']] = (ch.get('type'), ch.get('first_name') or ch.get('title'))
                print('CHATS:', chats)
                break
    except Exception as e:
        print(('tor' if proxy else 'direct'), 'ERR', str(e)[:80])
