import os
import json
import urllib.request
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("OPENROUTER_API_KEY")

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
req = urllib.request.Request(
    "https://openrouter.ai/api/v1/models",
    headers={"Authorization": f"Bearer {api_key}"}
)

with opener.open(req, timeout=15) as resp:
    data = json.loads(resp.read().decode("utf-8"))

models = data.get("data", [])
print(f"Total models available on OpenRouter: {len(models)}")

moonshot_models = [m["id"] for m in models if "moonshot" in m["id"].lower() or "kimi" in m["id"].lower()]
print("Moonshot / Kimi models found on OpenRouter:", moonshot_models)

if not moonshot_models:
    print("Other top models:")
    for m in models[:10]:
        print(" ", m["id"])
