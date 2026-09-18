import os
import httpx
import dotenv

dotenv.load_dotenv(r"C:\Soobshio_project\.env")

client = httpx.Client(verify=False, trust_env=False, timeout=10.0)

eleven_key = os.getenv("ELEVENLABS_API_KEY", "").strip()

r = client.get("https://api.elevenlabs.io/v1/voices", headers={"xi-api-key": eleven_key})
data = r.json()

print("=== ELEVENLABS FEMALE VOICES ===")
for v in data.get("voices", []):
    name = v.get("name")
    voice_id = v.get("voice_id")
    labels = v.get("labels", {})
    gender = labels.get("gender") or ""
    accent = labels.get("accent") or ""
    descript = labels.get("description") or labels.get("use_case") or ""
    if gender.lower() == "female" or "female" in str(labels).lower() or name in ["Rachel", "Domi", "Bella", "Elli", "Charlotte", "Freya", "Gigi", "Glinda", "Grace", "Serena", "Nicole", "Jessie", "Lily", "Sarah"]:
        print(f"Voice: {name:15} | ID: {voice_id} | Labels: {labels}")
