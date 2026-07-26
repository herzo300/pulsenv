#!/usr/bin/env python3
"""
Entry point for the monitoring Docker service.
Delegates to the services.monitoring package.
"""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from services.monitoring.main import run_forever

if __name__ == "__main__":
    try:
        asyncio.run(run_forever())
    except KeyboardInterrupt:
        import logging

        logging.getLogger(__name__).info("⏹️ Мониторинг остановлен")
