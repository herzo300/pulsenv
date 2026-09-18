import os

patch_path = r'c:\Soobshio_project\diff.patch'
if os.path.exists(patch_path):
    print("File exists, size:", os.path.getsize(patch_path))
    try:
        with open(patch_path, 'r', encoding='utf-16') as f:
            content = f.read()
        print("Successfully read with UTF-16, length:", len(content))
        lines = content.splitlines()
        print("First 30 lines:")
        for line in lines[:30]:
            print(line)
        # Search for some terms
        terms = ["dock", "polygon", "inactivity", "MapFilterPanel"]
        for term in terms:
            matches = [i for i, line in enumerate(lines) if term.lower() in line.lower()]
            print(f"Term '{term}': {len(matches)} matches")
            if matches:
                print("  First 3 matches at lines:", matches[:3])
                for idx in matches[:3]:
                    print(f"    Line {idx}: {lines[idx]}")
    except Exception as e:
        print("Error reading:", e)
else:
    print("File does not exist")
