import asyncio
import httpx
import json
import time
import os
from pathlib import Path

# Config
CAMERAS_FILE = Path("c:/Soobshio_project/public/cameras_nv_full.json")
STATUS_FILE = Path("c:/Soobshio_project/public/status_nv.json")
CHECK_INTERVAL = 300  # 5 minutes

async def check_camera(client, url):
    """
    Check if the HLS stream URL is reachable (.m3u8 check)
    """
    try:
        # We only check the head to save bandwidth
        start = time.perf_counter()
        resp = await client.head(url, timeout=5.0)
        end = time.perf_counter()
        
        return {
            "online": resp.status_code == 200,
            "latency": round((end - start) * 1000, 2),
            "status": resp.status_code
        }
    except Exception as e:
        return {"online": False, "error": str(e), "latency": 9999, "status": 0}

async def monitor_loop():
    print("Camera Uptime Monitor (Mini-Kuma) started...")
    
    async with httpx.AsyncClient(verify=False) as client:
        while True:
            if not CAMERAS_FILE.exists():
                print(f"File {CAMERAS_FILE} not found. Waiting 60s...")
                await asyncio.sleep(60)
                continue
                
            with open(CAMERAS_FILE, encoding='utf-8') as f:
                cameras = json.load(f)
            
            print(f"Checking {len(cameras)} cameras...")
            results = {}
            tasks = []
            
            for index, cam in enumerate(cameras):
                url = cam.get('s', '')
                if url:
                    tasks.append(check_camera(client, url))
            
            raw_statuses = await asyncio.gather(*tasks)
            
            # Form final status JSON
            final_status = {
                "updated_at": time.time(),
                "summary": {
                    "total": len(cameras),
                    "online": len([s for s in raw_statuses if s['online']]),
                    "offline": len([s for s in raw_statuses if not s['online']])
                },
                "cameras": []
            }
            
            for i, status in enumerate(raw_statuses):
                final_status["cameras"].append({
                    "n": cameras[i]['n'],
                    "s": cameras[i]['s'],
                    "status": "up" if status['online'] else "down",
                    "latency": status['latency'],
                    "code": status['status']
                })
            
            with open(STATUS_FILE, "w", encoding='utf-8') as f:
                json.dump(final_status, f, ensure_ascii=False, indent=2)
            
            print(f"Status updated: {final_status['summary']['online']}/{len(cameras)} online.")
            await asyncio.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    asyncio.run(monitor_loop())
