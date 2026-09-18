"""
Health-check all 130 NV cameras in parallel.
Probes HLS playlist URL (HEAD then GET-range), marks `online` field.
Writes back to public/cameras_nv.json with online/timestamp fields.
"""
import json
import time
import ssl
import urllib.request
import urllib.error
import concurrent.futures as cf
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SRC = ROOT / 'public' / 'cameras_nv.json'
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'


def check_camera(cam):
    """Return (cam, online: bool, status_code: int|str, latency_ms: int)."""
    url = cam.get('stream_url') or cam.get('s') or ''
    if not url:
        return cam, False, 'no_url', 0
    t0 = time.time()
    # Try HEAD first (cheaper), fall back to GET-range
    for method, extra_headers in [
        ('HEAD', {}),
        ('GET',  {'Range': 'bytes=0-1023'}),
    ]:
        try:
            req = urllib.request.Request(url, method=method, headers={'User-Agent': UA, **extra_headers})
            with urllib.request.urlopen(req, context=ctx, timeout=8) as r:
                if r.status in (200, 206):
                    ms = int((time.time() - t0) * 1000)
                    return cam, True, r.status, ms
        except urllib.error.HTTPError as e:
            # 404 means stream definitively down; try GET as backup only for 4xx other than 404
            if e.code == 404:
                return cam, False, 404, int((time.time() - t0) * 1000)
            continue
        except Exception:
            continue
    return cam, False, 'timeout', int((time.time() - t0) * 1000)


def main():
    cams = json.load(open(SRC, encoding='utf-8'))
    print(f'Loaded {len(cams)} cameras from {SRC}')

    results = []
    online_count = 0
    by_provider = {}

    with cf.ThreadPoolExecutor(max_workers=20) as ex:
        futures = {ex.submit(check_camera, c): i for i, c in enumerate(cams)}
        for fut in cf.as_completed(futures):
            i = futures[fut]
            cam, online, status, ms = fut.result()
            cams[i]['online'] = online
            cams[i]['status_code'] = status
            cams[i]['latency_ms'] = ms
            cams[i]['last_checked'] = int(time.time())
            prov = cam.get('provider', 'unknown')
            by_provider.setdefault(prov, {'total': 0, 'online': 0})
            by_provider[prov]['total'] += 1
            if online:
                by_provider[prov]['online'] += 1
                online_count += 1
            tag = '✅' if online else '❌'
            print(f'  [{i+1:3}/{len(cams)}] {tag} {cam.get("name","?")[:35]:35} | {prov:8} | {status} | {ms}ms')

    print(f'\n=== RESULT: {online_count}/{len(cams)} online ({online_count*100//len(cams)}%) ===')
    print('By provider:')
    for p, s in sorted(by_provider.items(), key=lambda x: -x[1]['total']):
        print(f'  {p:10}: {s["online"]:3}/{s["total"]:3} online')

    # Write back
    backup = SRC.with_suffix('.json.bak')
    backup.write_text(json.dumps(cams, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'\nBackup: {backup}')

    SRC.write_text(json.dumps(cams, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Updated: {SRC}')


if __name__ == '__main__':
    main()
