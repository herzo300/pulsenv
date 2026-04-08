#!/usr/bin/env python3
"""Start the Soobshio backend server with all services."""
import os
import sys
import asyncio
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(name)s] %(levelname)s %(message)s')
logger = logging.getLogger("StartBackend")

def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    # Ensure .env is loaded
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        pass

    logger.info("Starting Soobshio Backend...")
    logger.info(f"Database: {os.getenv('DATABASE_URL', 'sqlite:///./soobshio.db')[:50]}...")
    logger.info(f"AI Provider: {os.getenv('AI_TEXT_PROVIDER', 'litellm')}")

    # Start FastAPI server
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    host = os.getenv("HOST", "0.0.0.0")

    logger.info(f"Listening on {host}:{port}")
    uvicorn.run(
        "services.Backend.app:app",
        host=host,
        port=port,
        reload=False,
        log_level="info",
    )

if __name__ == "__main__":
    main()
