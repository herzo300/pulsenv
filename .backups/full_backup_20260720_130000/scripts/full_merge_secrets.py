import json


def merge_and_hide():
    base_file = "c:/Soobshio_project/public/cameras_nv.json"
    full_file = "c:/Soobshio_project/public/cameras_nv_full.json"
    pride_file = "c:/Soobshio_project/pride_cams.json"
    scan_file = "c:/Soobshio_project/camera_scan_results.json"

    with open(base_file, encoding="utf-8") as f:
        base_data = json.load(f)
        base_urls = {c["s"] for c in base_data}

    # Collect all available cameras from various sources
    all_cams = {c["s"]: c for c in base_data}

    def load_and_add(path):
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
                for c in data:
                    if c["s"] not in all_cams:
                        all_cams[c["s"]] = c
        except Exception:
            pass

    load_and_add(pride_file)
    load_and_add(scan_file)

    # Process "full" data to avoid duplicates and preserve metadata if exists
    try:
        with open(full_file, encoding="utf-8") as f:
            full_data = json.load(f)
            for c in full_data:
                if c["s"] in all_cams:
                    all_cams[c["s"]].update(c)
                else:
                    all_cams[c["s"]] = c
    except Exception:
        pass

    final_list = []
    secret_count = 0

    for s_url, cam in all_cams.items():
        # Assign secret flag
        is_secret = s_url not in base_urls
        cam["secret"] = is_secret
        if is_secret:
            secret_count += 1

        # Cleanup name if needed
        if "n" not in cam:
            cam["n"] = cam.get("name", "Camera " + s_url.split("/")[-1])

        final_list.append(cam)

    with open(full_file, "w", encoding="utf-8") as f:
        json.dump(final_list, f, ensure_ascii=False, indent=2)

    print(f"Total: {len(final_list)} cameras. Secret: {secret_count}")


if __name__ == "__main__":
    merge_and_hide()
