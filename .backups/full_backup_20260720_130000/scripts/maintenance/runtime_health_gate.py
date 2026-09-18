"""Fail-fast health gate for desktop/runtime startup."""

from __future__ import annotations

import json
import sys
from urllib.error import URLError
from urllib.request import urlopen


CHECKS = (
    "http://127.0.0.1:8000/health",
    "http://127.0.0.1:8000/api/runtime/monitoring-status",
    "http://127.0.0.1:8000/api/map/feed?limit=50",
)


def _check(url: str) -> dict[str, object]:
    try:
        with urlopen(url, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8", errors="replace"))
        return {"url": url, "ok": 200 <= response.status < 300, "keys": sorted(payload)[:8]}
    except (OSError, URLError, TimeoutError, json.JSONDecodeError) as exc:
        return {"url": url, "ok": False, "error": str(exc)}


def main() -> int:
    results = [_check(url) for url in CHECKS]
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0 if all(item["ok"] for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
