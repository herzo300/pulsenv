"""Safe runtime diagnostics for Puls Goroda services.

This script intentionally reports only presence/health booleans and never prints
secret values from .env.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parents[2]
ENV_KEYS = (
    "TG_API_ID",
    "TG_API_HASH",
    "TG_PHONE",
    "TG_BOT_TOKEN",
    "TARGET_CHANNEL",
    "VK_SERVICE_TOKEN",
    "JWT_SECRET",
    "PUBLIC_API_BASE_URL",
)


def _configured(name: str) -> bool:
    value = (os.getenv(name) or "").strip().strip('"').strip("'")
    return bool(value) and value.lower() not in {
        "change_me",
        "placeholder",
        "your_token_here",
    }


def _get_json(url: str) -> dict[str, object]:
    request = Request(url, headers={"User-Agent": "soobshio-doctor/1.0"})
    with urlopen(request, timeout=8) as response:
        raw = response.read().decode("utf-8", errors="replace")
    parsed = json.loads(raw)
    return parsed if isinstance(parsed, dict) else {"payload": parsed}


def main() -> int:
    load_dotenv(ROOT / ".env")
    backend = (os.getenv("PUBLIC_API_BASE_URL") or "http://127.0.0.1:8000").rstrip("/")
    status = {
        "env_present": {key: _configured(key) for key in ENV_KEYS},
        "session_files": {
            name: (ROOT / name).exists()
            for name in ("monitoring_session.session", "soobshio_session.session")
        },
        "backend": {},
    }

    for path in ("/health", "/api/runtime/monitoring-status", "/api/map/events"):
        url = f"{backend}{path}"
        try:
            payload = _get_json(url)
            status["backend"][path] = {
                "ok": True,
                "keys": sorted(payload.keys())[:12],
            }
        except (OSError, URLError, TimeoutError, json.JSONDecodeError) as error:
            status["backend"][path] = {"ok": False, "error": str(error)}

    print(json.dumps(status, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
