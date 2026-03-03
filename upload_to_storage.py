import os
import httpx
import asyncio
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = "https://xpainxohbdoruakcijyq.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

async def create_bucket(bucket_name):
    url = f"{SUPABASE_URL}/storage/v1/bucket"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    async with httpx.AsyncClient() as client:
        resp = await client.post(url, headers=headers, json={
            "id": bucket_name,
            "name": bucket_name,
            "public": True
        })
        print(f"Bucket status: {resp.status_code}")
        return resp.status_code in (200, 201, 204, 409)

async def upload_file(bucket, filename, file_path, content_type="text/html"):
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{filename}"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "x-upsert": "true",
        "Content-Type": content_type
    }
    
    with open(file_path, "rb") as f:
        data = f.read()
        
    async with httpx.AsyncClient() as client:
        resp = await client.post(url, headers=headers, content=data)
        if resp.status_code == 200:
            print(f"SUCCESS: {filename}")
            return f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{filename}"
        else:
            print(f"FAILED: {filename}: {resp.status_code}")
            return None

async def main():
    if not SUPABASE_KEY:
        print("ERROR: SUPABASE_SERVICE_ROLE_KEY not found")
        return

    await create_bucket("apps")
    
    # Inline Map
    with open("c:/Soobshio_project/public/map.html", "r", encoding="utf-8") as f: h = f.read()
    with open("c:/Soobshio_project/public/map_script.js", "r", encoding="utf-8") as f: j = f.read()
    map_final = h.replace('<script defer src="map_script.js"></script>', f'<script>{j}</script>')
    with open("c:/Soobshio_project/tmp/map_final.html", "w", encoding="utf-8") as f: f.write(map_final)

    # Inline Info
    with open("c:/Soobshio_project/public/info.html", "r", encoding="utf-8") as f: h = f.read()
    with open("c:/Soobshio_project/public/info_script_v2.js", "r", encoding="utf-8") as f: j = f.read()
    info_final = h.replace('<script defer src="info_script_v2.js"></script>', f'<script>{j}</script>')
    with open("c:/Soobshio_project/tmp/info_final.html", "w", encoding="utf-8") as f: f.write(info_final)

    map_url = await upload_file("apps", "map.html", "c:/Soobshio_project/tmp/map_final.html")
    info_url = await upload_file("apps", "info.html", "c:/Soobshio_project/tmp/info_final.html")
    
    if map_url and info_url:
        print(f"RESULTS_MAP: {map_url}")
        print(f"RESULTS_INFO: {info_url}")

if __name__ == "__main__":
    asyncio.run(main())
