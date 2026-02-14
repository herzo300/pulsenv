"""Check infographic page via requests with headers"""
import urllib.request
req = urllib.request.Request(
    'https://anthropic-proxy.uiredepositionherzo.workers.dev/info',
    headers={'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'}
)
try:
    r = urllib.request.urlopen(req, timeout=10)
    body = r.read()
    print(f'Status: {r.status}, Size: {len(body)} bytes')
    text = body.decode('utf-8', errors='replace')
    # Check key elements
    checks = ['72 датасет', 'BudgetCard', 'PropertyCard', 'safe_int', 'territory_plans', 'labor_safety', 'appeals']
    for c in checks:
        print(f'  {c}: {"✓" if c in text else "✗"}')
except Exception as e:
    print(f'Error: {e}')
    # Try checking worker.js directly
    print('\nChecking local worker.js instead...')
    with open('cloudflare-worker/worker.js', 'r', encoding='utf-8') as f:
        text = f.read()
    print(f'worker.js: {len(text)} chars')
    checks = ['BudgetCard', 'PropertyCard', 'safe_int', 'territory_plans', 'labor_safety', 'appeals', 'datasets_total']
    for c in checks:
        print(f'  {c}: {"✓" if c in text else "✗"}')
