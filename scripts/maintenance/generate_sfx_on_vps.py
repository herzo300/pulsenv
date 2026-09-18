# scripts/maintenance/generate_sfx_on_vps.py
import os
import requests
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Sound output directory on the VPS
OUTPUT_DIR = "/app/static/sounds"
os.makedirs(OUTPUT_DIR, exist_ok=True)

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY") or "sk_8f92196bed673980a71f32c31d8ae0585ca410c5d3511417"
SFX_ENGINE_API_KEY = os.getenv("SFX_ENGINE") or "sk_6bafxi5s6ce5njm6k2y3ft5hoq54d5453sd4eza"

SOUNDS_TO_GENERATE = [
    {
        "filename": "menu_confirm.mp3",
        "prompt": "futuristic clean digital sci-fi confirmation beep button click",
        "duration": 1.0
    },
    {
        "filename": "menu_notification.mp3",
        "prompt": "soft melodic high-tech smart city alert notification chime",
        "duration": 1.5
    },
    {
        "filename": "splash_gravity.mp3",
        "prompt": "deep cinematic electronic ambient drop sub-bass swell intro",
        "duration": 3.0
    },
    {
        "filename": "vip_upgrade.mp3",
        "prompt": "triumphant bright golden shimmering premium success reward chime",
        "duration": 2.5
    }
]

def generate_via_elevenlabs(prompt, duration, output_path):
    logger.info(f"Attempting to generate sound via ElevenLabs: '{prompt}'")
    url = "https://api.elevenlabs.io/v1/sound-generation"
    headers = {
        "xi-api-key": ELEVENLABS_API_KEY,
        "Content-Type": "application/json"
    }
    payload = {
        "text": prompt,
        "duration_seconds": duration,
        "prompt_influence": 0.3
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        if response.status_code == 200:
            with open(output_path, "wb") as f:
                f.write(response.content)
            logger.info(f"Successfully generated: {output_path} (ElevenLabs)")
            return True
        else:
            logger.warning(f"ElevenLabs failed ({response.status_code}): {response.text}")
    except Exception as e:
        logger.error(f"ElevenLabs error: {e}")
    return False

def generate_via_sfx_engine(prompt, duration, output_path):
    logger.info(f"Attempting to generate sound via SFX Engine: '{prompt}'")
    # Endpoint for SFX Engine (mocking call based on typical engine architecture)
    url = "https://api.sfxengine.com/v1/generate"
    headers = {
        "Authorization": f"Bearer {SFX_ENGINE_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "prompt": prompt,
        "duration": duration
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        if response.status_code == 200:
            with open(output_path, "wb") as f:
                f.write(response.content)
            logger.info(f"Successfully generated: {output_path} (SFX Engine)")
            return True
        else:
            logger.warning(f"SFX Engine failed ({response.status_code}): {response.text}")
    except Exception as e:
        logger.error(f"SFX Engine error: {e}")
    return False

def main():
    logger.info("=== STARTING AI SFX GENERATION ON VPS ===")
    for sound in SOUNDS_TO_GENERATE:
        path = os.path.join(OUTPUT_DIR, sound["filename"])
        
        # Try ElevenLabs first
        success = generate_via_elevenlabs(sound["prompt"], sound["duration"], path)
        
        # Fallback to SFX Engine
        if not success:
            success = generate_via_sfx_engine(sound["prompt"], sound["duration"], path)
            
        if not success:
            logger.error(f"Failed to generate sound for {sound['filename']}")

if __name__ == "__main__":
    main()
