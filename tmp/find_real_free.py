import asyncio
import httpx

async def find_free_ids():
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get("https://mvsep.com/api/app/algorithms")
        algos = resp.json()
        for a in algos:
            if not a.get("premium"): # Some have a premium flag
                print(f"ID: {a['id']} - Name: {a['name']} - Scope: {a.get('scope')}")

if __name__ == "__main__":
    asyncio.run(find_free_ids())
