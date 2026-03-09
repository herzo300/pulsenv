import requests
import json
import re

try:
    r = requests.get('https://nv86.ru/map/cam/', verify=False)
    r.encoding = 'utf-8' # Force utf-8
    matches = re.search(r'\[\{"lat":.*?\}\]', r.text)
    if not matches:
        print("Could not find balloons array")
        import sys; sys.exit(1)
        
    data = json.loads(matches.group(0))
    pride_cams = []
    
    for d in data:
        name = d.get('name', '').replace('<br>', ' ').strip()
        url = d.get('url', '')
        if '<iframe' in url:
            iframe_match = re.search(r'src="([^"]+)"', url)
            if iframe_match:
                url = iframe_match.group(1)
        
        # fix url
        if url.startswith('//'):
            url = 'https:' + url
        
        # for pride nginx streams
        if 'nginx' in url and 'pride-net' in url and not url.endswith('.m3u8'):
            url = url.rstrip('/') + '/index.m3u8'
            
        lat = float(d.get('lat', 0))
        lon = float(d.get('lon', 0))
        
        if lat != 0 and lon != 0 and url:
            pride_cams.append({
                'n': name + ' (Прайд)',
                'lat': lat,
                'lng': lon,
                's': url
            })
            
    print(f'Parsed {len(pride_cams)} Pride cameras with correct encoding.')
    
    # Let's read the existing ones and combine
    import os
    target = 'services/Frontend/assets/cameras_nv.json'
    with open(target, 'r', encoding='utf-8') as f:
        existing = json.load(f)
        
    # We will only append Pride cameras that don't share the exact same coordinates (just to be safe, though Dantser vs Pride usually are different cameras)
    # Actually, we can just append them all. But maybe use the URL to deduplicate?
    existing_urls = set(c.get('s') for c in existing)
    
    added = 0
    for p in pride_cams:
        if p['s'] not in existing_urls:
            existing.append(p)
            existing_urls.add(p['s'])
            added += 1
            
    with open(target, 'w', encoding='utf-8') as f:
        json.dump(existing, f, ensure_ascii=False, indent=2)
        
    print(f'Successfully added {added} new cameras to existing {len(existing) - added} cameras. Total: {len(existing)}')
except Exception as e:
    print('Error:', e)
