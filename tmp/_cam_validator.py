import json
import requests
import concurrent.futures

def check_stream(url):
    if not url or not url.startswith('http'):
        return False, "Invalid URL"
    try:
        # Check only headers to save time/bandwidth
        response = requests.head(url, timeout=3, allow_redirects=True, verify=False)
        if response.status_code == 200:
            return True, "Active"
        # If HEAD fails, try a small GET
        response = requests.get(url, timeout=3, stream=True, verify=False)
        if response.status_code == 200:
            return True, "Active"
        return False, f"Status {response.status_code}"
    except Exception as e:
        return False, str(e)

def process_cams():
    # Load both files
    files = [
        'services/Frontend/assets/cameras_nv.json',
        'public/cameras_nv_fixed.json'
    ]
    
    all_cams = []
    seen_urls = set()
    
    for f_path in files:
        try:
            with open(f_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                for item in data:
                    url = item.get('s')
                    if url and url not in seen_urls:
                        all_cams.append(item)
                        seen_urls.add(url)
        except Exception as e:
            print(f"Error reading {f_path}: {e}")

    print(f"Total unique cameras to check: {len(all_cams)}")
    
    results = []
    # Use ThreadPoolExecutor for faster checking
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        future_to_cam = {executor.submit(check_stream, cam.get('s')): cam for cam in all_cams}
        for future in concurrent.futures.as_completed(future_to_cam):
            cam = future_to_cam[future]
            try:
                is_active, status = future.result()
                cam['active'] = is_active
                cam['status_msg'] = status
                results.append(cam)
            except Exception as e:
                cam['active'] = False
                cam['status_msg'] = str(e)
                results.append(cam)

    # Save finalized list
    with open('services/Frontend/assets/cameras_nv.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    
    # Generate Report
    active = [c for c in results if c['active']]
    inactive = [c for c in results if not c['active']]
    
    print("\n--- CAMERA AUDIT REPORT ---")
    print(f"Total: {len(results)}")
    print(f"Active: {len(active)}")
    print(f"Inactive: {len(inactive)}")
    
    # Group errors
    errors = {}
    for c in inactive:
        msg = c['status_msg']
        errors[msg] = errors.get(msg, 0) + 1
    
    print("\nCommon failure reasons:")
    for msg, count in sorted(errors.items(), key=lambda x: x[1], reverse=True):
        print(f"- {msg}: {count}")

if __name__ == "__main__":
    process_cams()
