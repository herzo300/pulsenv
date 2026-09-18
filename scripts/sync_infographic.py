#!/usr/bin/env python3
"""Download OpenData datasets and rebuild infographic JSON."""

from __future__ import annotations

import asyncio
import logging
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.business.infographic_sync import update_infographic_from_opendata  # noqa: E402


async def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    info = await update_infographic_from_opendata(force_download=True)
    blocks = len(info.get("blocks") or [])
    live = info.get("datasets_live", 0)
    print(f"Infographic updated: {blocks} blocks, {live} live datasets")


if __name__ == "__main__":
    asyncio.run(main())
