import os

targets = [
    'services/Frontend/lib/screens',
    'services/Frontend/lib/services',
    'services/Frontend/lib/widgets',
    'services/Backend/routers',
    'public',
    'scripts'
]

results = []
for t in targets:
    if os.path.exists(t):
        for root, dirs, files in os.walk(t):
            for f in files:
                if f.endswith(('.dart', '.py', '.js', '.html')):
                    p = os.path.join(root, f)
                    try:
                        with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                            lines = sum(1 for _ in fp)
                        if lines > 600:
                            results.append((lines, p))
                    except Exception:
                        pass

results.sort(reverse=True, key=lambda x: x[0])
print(f"Targeted Scan: Found {len(results)} files over 600 lines:")
for lines, p in results:
    print(f"{lines:6d} lines: {p}")
