import os, httpx, json
token = os.getenv('TG_BOT_TOKEN','').strip('"')
# try both empty and last update
r = httpx.get(f'https://api.telegram.org/bot{token}/getUpdates?limit=100', proxy='socks5://172.18.0.2:9050', timeout=40)
d = r.json()
print('total updates:', len(d.get('result', [])))
chats = {}
for u in d.get('result', []):
    m = u.get('message') or u.get('edited_message') or u.get('channel_post') or u.get('callback_query', {}).get('message', {})
    ch = m.get('chat', {}) if isinstance(m, dict) else {}
    if ch.get('id'): chats[ch['id']] = (ch.get('type'), ch.get('first_name') or ch.get('title') or ch.get('username'))
print('CHATS:', json.dumps(chats, ensure_ascii=False))
