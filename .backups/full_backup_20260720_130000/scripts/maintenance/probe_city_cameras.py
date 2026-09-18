#!/usr/bin/env python3
"""Probe Nizhnevartovsk camera HLS streams and mark streamable flags in JSON."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from services.business.camera_stream_utils import (  # noqa: E402
    normalize_camera_stream_url,
    probe_camera_stream_url,
)

CAMERA_FILES = (
    ROOT / "services" / "Frontend" / "assets" / "cameras_nv.json",
    ROOT / "public" / "cameras_nv_full.json",
    ROOT / "public" / "cameras_nv.json",
)
DEFAULT_TIMEOUT = 8.0
DEFAULT_WORKERS = 16


def _raw_url(item: dict) -> str:
    return str(item.get("s") or item.get("stream_url") or item.get("url") or "").strip()


def probe_file(path: Path, *, timeout: float, workers: int, apply: bool, retries: int) -> dict[str, int]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError(f"{path} must contain a JSON array")

    normalized_urls: dict[str, tuple[bool, int | None, str, str]] = {}
    unique_urls = sorted(
        {
            normalize_camera_stream_url(_raw_url(item))
            for item in payload
            if _raw_url(item)
        }
    )

    def _probe_one(url: str) -> tuple[str, bool, int | None, str, str]:
        ok = False
        status: int | None = None
        error = ""
        normalized = normalize_camera_stream_url(url)
        for _ in range(max(1, retries)):
            ok, status, error, normalized = probe_camera_stream_url(
                normalized,
                timeout_seconds=timeout,
            )
            if ok:
                break
        return url, ok, status, error, normalized

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for url, ok, status, error, normalized in pool.map(_probe_one, unique_urls):
            normalized_urls[url] = (ok, status, error, normalized)

    online = 0
    offline = 0
    for item in payload:
        if not isinstance(item, dict):
            continue
        raw = _raw_url(item)
        if not raw:
            continue
        normalized = normalize_camera_stream_url(raw)
        ok, status, error, resolved = normalized_urls.get(
            normalized, (False, None, "missing", normalized)
        )
        item["s"] = resolved
        item["stream_url"] = resolved
        item["streamable"] = bool(ok)
        item["secret"] = False
        item["probe_http_status"] = status
        if error:
            item["probe_error"] = error
        elif "probe_error" in item:
            item.pop("probe_error", None)
        if ok:
            online += 1
        else:
            offline += 1

    summary = {
        "file": str(path),
        "total_rows": len(payload),
        "online": online,
        "offline": offline,
        "unique_urls": len(unique_urls),
    }

    if apply:
        path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write normalized URLs and streamable flags back to JSON files",
    )
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    args = parser.parse_args()

    totals = {"online": 0, "offline": 0, "files": 0}
    for path in CAMERA_FILES:
        if not path.exists():
            print(f"skip missing {path}")
            continue
        summary = probe_file(
            path,
            timeout=args.timeout,
            workers=args.workers,
            apply=args.apply,
            retries=args.retries,
        )
        totals["files"] += 1
        totals["online"] = max(totals["online"], summary["online"])
        totals["offline"] = max(totals["offline"], summary["offline"])
        print(json.dumps(summary, ensure_ascii=False))

    print(
        f"summary: files={totals['files']} online={totals['online']} offline={totals['offline']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
