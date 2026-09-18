import os
import socket
import httpx

token = os.getenv('TG_BOT_TOKEN', '').strip('"')
proxy = 'socks5://172.18.0.2:9050'

proxy_ip = '172.18.0.2'
print('using tor at', proxy_ip)

chats = {}
try:
    with httpx.Client(proxy=proxy, timeout=40) as c:
        r = c.get(f'https://api.telegram.org/bot{token}/getUpdates?limit=20')
        for u in r.json().get('result', []):
            m = u.get('message') or u.get('edited_message') or {}
            ch = m.get('chat', {})
            if ch.get('id'):
                chats[ch['id']] = (ch.get('type'), ch.get('first_name') or ch.get('title'))
except Exception as e:
    print('getUpdates err:', str(e)[:100])

print('CHATS:', chats)

if chats:
    chat_id = list(chats.keys())[0]
    msg = (
        'Пульс города v1.0.3 (ARM64, 52.3 МБ)\n\n'
        'Ссылка: https://45.153.68.59/app-arm64-v8a-release.apk\n'
        'MD5: 5f630bc9e8b64205b054fc11d3880402\n\n'
        'Что нового: бегущая строка со свайпом и обновлением каждые 5 мин, '
        'светлый анимированный фон Гермеса, эффекты наложений на полном экране камер, '
        'WebGL-двойник с текстурами офлайн, security-харденинг (ключи API вынесены на сервер).'
    )
    try:
        r2 = httpx.post(
            f'https://api.telegram.org/bot{token}/sendMessage',
            data={'chat_id': chat_id, 'text': msg},
            proxy=proxy, timeout=60,
        )
        print('send:', r2.status_code, r2.text[:150])
    except Exception as e:
        print('send err:', str(e)[:120])
