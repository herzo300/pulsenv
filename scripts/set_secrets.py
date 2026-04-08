import json
import os

base_path = 'c:/Soobshio_project/public/cameras_nv.json'
full_path = 'c:/Soobshio_project/public/cameras_nv_full.json'

with open(base_path, encoding='utf-8') as f:
    base_urls = {i['s'] for i in json.load(f)}

with open(full_path, encoding='utf-8') as f:
    full_data = json.load(f)

for item in full_data:
    item['secret'] = item['s'] not in base_urls

with open(full_path, 'w', encoding='utf-8') as f:
    json.dump(full_data, f, ensure_ascii=False, indent=2)

secret_count = len([i for i in full_data if i.get('secret')])
print(f"Successfully marked {secret_count} cameras as secret.")
