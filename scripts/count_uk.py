import re, sys

sys.stdout.reconfigure(encoding='utf-8')
data = open('services/Frontend/lib/services/uk_fallback_data.dart', encoding='utf-8').read()
names = re.findall(r"'name': '([^']+)'", data)
print(f"Total UK count: {len(names)}")
for i, n in enumerate(names, 1):
    print(f"{i}. {n}")
