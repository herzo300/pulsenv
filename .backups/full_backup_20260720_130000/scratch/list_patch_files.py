with open(r'c:\Soobshio_project\diff.patch', 'r', encoding='utf-16') as f:
    lines = f.readlines()

for line in lines:
    if line.startswith('diff --git'):
        print(line.strip())
