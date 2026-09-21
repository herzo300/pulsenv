import os
import httpx

token = os.getenv('TG_BOT_TOKEN', '').strip('"')
proxy = 'socks5://172.18.0.2:9050'
chat_id = 8396585653

msg = (
    'Пульс города v1.0.3+4 (ARM64, 89.2 МБ)\n\n'
    'Ссылка: https://45.153.68.59/app-arm64-v8a-release.apk\n'
    'MD5: 886d289a17b4498d2692fa17334238e4\n\n'
    'Что нового: единый Зд-двойник (canvas + WebGL), бегущая строка со свайпом, '
    'светлый фон Гермеса, ИИ-мониторинг дома 24/7, человечки-цифры в сканере счётчиков, '
    'GPS-фиксы, visual-search оживлён.\n\n'
    'Привет, Андрей! Бот Пульс города на связи.'
)
r = httpx.post(
    f'https://api.telegram.org/bot{token}/sendMessage',
    data={'chat_id': chat_id, 'text': msg},
    proxy=proxy, timeout=60,
)
print('send:', r.status_code, r.text[:150])
