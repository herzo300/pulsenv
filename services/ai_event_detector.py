import asyncio
import httpx
import json
import time
import os
import base64
from pathlib import Path
from datetime import datetime
import uuid

# Config
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
CAMERAS_FILE = Path("c:/Soobshio_project/public/cameras_nv_full.json")
STATUS_FILE = Path("c:/Soobshio_project/public/status_nv.json")
EVENTS_FILE = Path("c:/Soobshio_project/public/ai_events.json")
SCAN_INTERVAL = 600  # 10 minutes for global patrol
MAX_PARALLEL_SCANS = 5

async def capture_frame(camera_url):
    """
    In production, this uses ffmpeg to grab a frame.
    For this implementation, we simulate it by assuming we have access to a snapshot service
    or we use a placeholder frame for analysis (in reality, you'd call a local ffmpeg script).
    """
    # Simulate frame capture
    return "base64_encoded_frame_data_here"

async def analyze_scene(client, camera_name, frame_data, custom_targets=None):
    """
    Use Gemini 2.0 Flash to detect unusual city situations.
    """
    if not GEMINI_API_KEY:
        return None

    prompt = f"Ты — эксперт по городской безопасности. Анализируешь кадр с камеры '{camera_name}'. "
    prompt += "Если видишь ЧП (ДТП, пожар, драка, незаконная парковка, толпы людей, мусор), опиши это кратко. "
    prompt += "Если ничего особенного нет, ответь 'NORMAL'. "
    
    if custom_targets:
        prompt += f"Также ищи следующие объекты: {', '.join(custom_targets)}. Если найдешь - сообщи детали."

    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [{
                "parts": [
                    {"text": prompt},
                    # In true implementation, we'd send the actual image bytes:
                    # {"inline_data": {"mime_type": "image/jpeg", "data": frame_data}}
                ]
            }]
        }
        
        resp = await client.post(url, json=payload, timeout=20.0)
        if resp.status_code == 200:
            text = resp.json()['candidates'][0]['content']['parts'][0]['text']
            if "NORMAL" in text.upper() and len(text) < 15:
                return None
            return text
    except Exception as e:
        print(f"AI Scan Error for {camera_name}: {e}")
    return None

async def create_map_marker(event_text, camera):
    """
    Create a marker in the 'complaints' system so it appears on the map.
    """
    event_id = str(uuid.uuid4())
    category = "ЧП" if "ЧП" in event_text or "ДТП" in event_text else "Безопасность"
    
    event_data = {
        "id": event_id,
        "summary": "🤖 ИИ: " + event_text[:100] + "...",
        "description": event_text,
        "category": category,
        "status": "open",
        "lat": camera.get('lat'),
        "lng": camera.get('lng'),
        "address": camera.get('n', 'Городская камера'),
        "created_at": datetime.now().isoformat(),
        "source_label": "AI Monitor",
        "is_ai_detected": True
    }
    
    # Save to local file for real-time map feed fallback
    try:
        if EVENTS_FILE.exists():
            with open(EVENTS_FILE, "r", encoding='utf-8') as f:
                events = json.load(f)
        else:
            events = []
        
        events.append(event_data)
        # Keep only last 50 AI events
        events = events[-50:]
        
        with open(EVENTS_FILE, "w", encoding='utf-8') as f:
            json.dump(events, f, ensure_ascii=False, indent=2)
            
        print(f"📍 New AI Marker: {event_data['summary']}")
    except Exception as e:
        print(f"Error saving AI event: {e}")

async def monitor_loop():
    print("🤖 AI City Event Detector (Vision Patrol) active...")
    
    async with httpx.AsyncClient() as client:
        while True:
            if not CAMERAS_FILE.exists():
                await asyncio.sleep(60)
                continue
            
            with open(CAMERAS_FILE, encoding='utf-8') as f:
                cameras = json.load(f)
            
            # Global Patrol: Pick 10 random cameras each cycle to monitor city-wide
            import random
            patrol_subset = random.sample(cameras, min(10, len(cameras)))
            
            for cam in patrol_subset:
                # 1. Capture (simulate)
                frame = await capture_frame(cam.get('s'))
                
                # 2. Analyze
                detection = await analyze_scene(client, cam.get('n'), frame)
                
                if detection:
                    # 3. Mark on map
                    await create_map_marker(detection, cam)
                
                # Yield to other tasks
                await asyncio.sleep(1)
            
            await asyncio.sleep(SCAN_INTERVAL)

if __name__ == "__main__":
    asyncio.run(monitor_loop())
