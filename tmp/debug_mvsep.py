import os
import asyncio
import httpx
from pathlib import Path

# Force load key from .env if not manually set
from dotenv import load_dotenv
load_dotenv()

MVSEP_API_KEY = os.getenv("MVSEP_API_KEY")

async def test_mvsep():
    input_path = Path("c:/Soobshio_project/tmp/test.ogg")
    
    # Use different form field names?
    # According to docs I read: `audiofile` and `api_token`
    
    async with httpx.AsyncClient(timeout=300) as client:
        files = {"audiofile": ("test.ogg", open(input_path, "rb"), "audio/ogg")}
        data = {
            "api_token": MVSEP_API_KEY,
            "sep_type": "26", # MDX23C
            "output_format": "1"
        }
        
        print(f"Submitting with token: {MVSEP_API_KEY[:4]}...")
        r = await client.post("https://mvsep.com/api/separation/create", files=files, data=data)
        print(f"Status: {r.status_code}")
        print(f"Response: {r.text}")

if __name__ == "__main__":
    asyncio.run(test_mvsep())
