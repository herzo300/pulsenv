"""Test what CF Worker returns for /map"""
import urllib.request
req = urllib.request.Request(
    'https://anthropic-proxy.uiredepositionherzo.workers.dev/map',
    headers={'User-Agent': 'Mozilla/5.0'}
)
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = resp.read()
        print(f"Status: {resp.status}")
        print(f"Content-Length: {len(data)}")
        print(f"Content-Type: {resp.headers.get('Content-Type')}")
        text = data.decode('utf-8', errors='replace')
        # Check for key elements
        print(f"Has 'fabNew': {'fabNew' in text}")
        print(f"Has 'cfOverlay': {'cfOverlay' in text}")
        print(f"Has 'buildCatFilters': {'buildCatFilters' in text}")
        print(f"Has '<script>': {'<script>' in text}")
        print(f"Has 'initMap': {'initMap' in text}")
        print(f"First 500: {text[:500]}")
        print(f"Last 500: {text[-500:]}")
except Exception as e:
    print(f"Error: {e}")
