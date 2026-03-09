import requests
import json
import re

try:
    r = requests.get('https://nv86.ru/map/cam/', verify=False)
    # The balloons variable might be declared differently. Let's just blindly search for JSON arrays containing "lat": and "lon":
    matches = re.search(r'\[\{"lat":.*?\}\]', r.text)
    if not matches:
        print("Could not find balloons array... Here is the snippet:")
        print(r.text[:500])
        import sys
        sys.exit(1)
        
    data = json.loads(matches.group(0))
    pride_cams = []
    
    for d in data:
        name = d.get('name', '').replace('<br>', ' ').strip()
        url = d.get('url', '')
        if '<iframe' in url:
            iframe_match = re.search(r'src="([^"]+)"', url)
            if iframe_match:
                url = iframe_match.group(1)
        
        # We need an m3u8 stream right? We'll see what the url points to.
        # Usually nv86 embeds: https://nginx04.pride-net.ru/mir32/index.m3u8
        lat = float(d.get('lat', 0))
        lon = float(d.get('lon', 0))
        
        if lat != 0 and lon != 0:
            pride_cams.append({
                'n': name + ' (Прайд)',
                'lat': lat,
                'lng': lon,
                's': url
            })
            
    print(f'Parsed {len(pride_cams)} Pride cameras.')
    with open('pride_cams.json', 'w', encoding='utf-8') as f:
        json.dump(pride_cams, f, ensure_ascii=False, indent=2)
except Exception as e:
    print('Error:', e)
