import os, httpx
# ZAI: check if key configured
zkey = os.getenv('ZAI_API_KEY','')
zurl = os.getenv('ZAI_BASE_URL','')
print('ZAI key len:', len(zkey), 'url:', zurl)
gemma = os.getenv('GEMMA_CLOUD_API_KEY','')
print('GEMMA key len:', len(gemma))
# Try ZAI chat
if zkey and zurl:
    try:
        r = httpx.post(f'{zurl}/chat/completions',
            headers={'Authorization': 'Bearer '+zkey, 'Content-Type':'application/json'},
            json={'model': os.getenv('ZAI_TEXT_MODEL','glm-5-turbo'), 'messages':[{'role':'user','content':'Say OK'}], 'max_tokens':10},
            timeout=30)
        print('ZAI:', r.status_code, r.text[:150])
    except Exception as e:
        print('ZAI ERR:', str(e)[:80])
