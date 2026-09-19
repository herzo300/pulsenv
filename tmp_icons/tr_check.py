import httpx
tr = 'sk-wsjrj1L8KPvOnbfpfZRkvIPzmDuXYiOWrpDCjnuI3qzFccn1'
try:
    r = httpx.post('https://api.tokenrouter.com/v1/chat/completions',
        headers={'Authorization': 'Bearer '+tr, 'Content-Type':'application/json'},
        json={'model':'moonshotai/kimi-k3-free','messages':[{'role':'user','content':'Say OK'}],'max_tokens':10},
        timeout=40)
    print('TokenRouter kimi:', r.status_code, r.text[:200])
except Exception as e:
    print('ERR', str(e)[:80])
# list models again
try:
    r2 = httpx.get('https://api.tokenrouter.com/v1/models', headers={'Authorization': 'Bearer '+tr}, timeout=20)
    print('models:', [m['id'] for m in r2.json().get('data',[])])
except Exception as e:
    print('models ERR', str(e)[:60])
