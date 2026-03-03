import asyncio
import httpx

async def find_free_algos():
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get("https://mvsep.com/api/app/algorithms")
        algos = resp.json()
        for a in algos:
            # Look for indicators of free access
            # Some might have 'price' or 'premium' flags
            print(f"ID: {a['id']} - Name: {a['name']} - Scope: {a.get('scope')} - Restricted: {a.get('restricted_to')}")

if __name__ == "__main__":
    asyncio.run(find_free_algos())
