"""Quick bot test — send /start and check response"""
import asyncio
import httpx

BOT_TOKEN = '8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g'
API = f'https://api.telegram.org/bot{BOT_TOKEN}'

async def test():
    async with httpx.AsyncClient(timeout=15) as c:
        # Get bot info
        r = await c.get(f'{API}/getMe')
        me = r.json()['result']
        print(f"Bot: @{me['username']} ({me['first_name']})")
        
        # Get updates
        r2 = await c.get(f'{API}/getUpdates', params={'limit': 3, 'offset': -3})
        updates = r2.json().get('result', [])
        print(f"Recent updates: {len(updates)}")
        for u in updates[-3:]:
            msg = u.get('message', {})
            text = msg.get('text', '')[:50]
            user = msg.get('from', {}).get('username', '?')
            print(f"  @{user}: {text}")
        
        # Check webhook (should be none for polling)
        r3 = await c.get(f'{API}/getWebhookInfo')
        wh = r3.json()['result']
        print(f"Webhook: {wh.get('url', 'none')}")
        print(f"Pending updates: {wh.get('pending_update_count', 0)}")
        
        # Get my commands
        r4 = await c.get(f'{API}/getMyCommands')
        cmds = r4.json().get('result', [])
        print(f"Commands: {len(cmds)}")
        for cmd in cmds:
            print(f"  /{cmd['command']} — {cmd['description']}")

asyncio.run(test())
