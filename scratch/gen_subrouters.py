import os
base = r'c:\Soobshio_project\services\Backend\routers'

files = {
    'map_tiles.py': 'from fastapi import APIRouter\nrouter = APIRouter(prefix= /map/tiles, tags=[map-tiles])\n@router.get(/ping)\ndef ping(): return {status: ok}\n',
    'map_layers.py': 'from fastapi import APIRouter\nrouter = APIRouter(prefix=/map/layers, tags=[map-layers])\n@router.get(/ping)\ndef ping(): return {status: ok}\n',
    'report_crud.py': 'from fastapi import APIRouter\nrouter = APIRouter(prefix=/reports/crud, tags=[report-crud])\n@router.get(/ping)\ndef ping(): return {status: ok}\n',
    'report_export.py': 'from fastapi import APIRouter\nrouter = APIRouter(prefix=/reports/export, tags=[report-export])\n@router.get(/ping)\ndef ping(): return {status: ok}\n',
    'gamification_xp.py': 'from fastapi import APIRouter\nrouter = APIRouter(prefix=/gamification/xp, tags=[gamification-xp])\n@router.get(/ping)\ndef ping(): return {status: ok}\n',
    'gamification_leaderboard.py': 'from fastapi import APIRouter\nrouter = APIRouter(prefix=/gamification/leaderboard, tags=[gamification-lb])\n@router.get(/ping)\ndef ping(): return {status: ok}\n'
}

for fname, content in files.items():
    with open(os.path.join(base, fname), 'w', encoding='utf-8') as f:
        f.write(content)
print('Subrouters successfully created!')
