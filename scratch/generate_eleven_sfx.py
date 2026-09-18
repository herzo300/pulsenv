import os
import time
import httpx
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

client = httpx.Client(verify=False, trust_env=False, timeout=20.0)

eleven_key = os.getenv("ELEVENLABS_API_KEY", "").strip()
url = "https://api.elevenlabs.io/v1/sound-generation"

headers = {
    "xi-api-key": eleven_key,
    "Content-Type": "application/json"
}

sfx_prompts = {
    "ui_click_soft.mp3": "soft subtle organic glass tap, gentle minimalist UI button click, warm clean acoustic pop, high quality",
    "ui_toggle_soft.mp3": "delicate soft switch pop, subtle organic UI toggle sound, smooth glass feel, modern UI sound",
    "ui_alert_soft.mp3": "soft elegant alert chime, gentle warning tone, non-intrusive warm harmonic notification"
}

out_dir = r"C:\Soobshio_project\public\audio"
os.makedirs(out_dir, exist_ok=True)

print("=== GENERATING REMAINING SOFT UI SOUNDS (duration >= 0.5s) ===")

for filename, prompt in sfx_prompts.items():
    out_path = os.path.join(out_dir, filename)
    print(f"Generating {filename}...")
    payload = {
        "text": prompt,
        "duration_seconds": 0.6,
        "prompt_influence": 0.4
    }
    try:
        t0 = time.time()
        r = client.post(url, json=payload, headers=headers)
        dt = (time.time() - t0) * 1000
        if r.status_code == 200:
            with open(out_path, "wb") as f:
                f.write(r.content)
            print(f"   [SUCCESS] Saved {filename} ({len(r.content)} bytes) in {dt:.1f}ms!")
        else:
            print(f"   [FAIL] Status {r.status_code}: {r.text[:150]}")
    except Exception as e:
        print(f"   [ERR]: {e}")

print("=== SFX GENERATION COMPLETE ===")
