"""Тест всех API через SOCKS5 прокси (ручная реализация)"""
import socket
import ssl
import json
import time
import struct

PROXY_HOST = "46.183.30.125"
PROXY_PORT = 14520
PROXY_USER = "user360810"
PROXY_PASS = "0dkmyj"


def socks5_connect(target_host, target_port, timeout=15):
    """Подключение через SOCKS5 с авторизацией"""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect((PROXY_HOST, PROXY_PORT))

    # SOCKS5 greeting: user/pass auth
    s.send(b'\x05\x01\x02')
    resp = s.recv(2)
    if resp[0] != 5 or resp[1] != 2:
        raise Exception(f"SOCKS5 greeting failed: {resp.hex()}")

    # Auth
    auth = b'\x01' + bytes([len(PROXY_USER)]) + PROXY_USER.encode()
    auth += bytes([len(PROXY_PASS)]) + PROXY_PASS.encode()
    s.send(auth)
    ar = s.recv(2)
    if ar[1] != 0:
        raise Exception("SOCKS5 auth failed")

    # Connect request
    req = b'\x05\x01\x00\x03'  # VER, CMD=CONNECT, RSV, ATYP=DOMAIN
    req += bytes([len(target_host)]) + target_host.encode()
    req += struct.pack('!H', target_port)
    s.send(req)

    resp = s.recv(10)
    if resp[1] != 0:
        raise Exception(f"SOCKS5 connect failed: status={resp[1]}")

    return s


def https_get(host, path, timeout=15):
    """HTTPS GET через SOCKS5"""
    raw = socks5_connect(host, 443, timeout)

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    s = ctx.wrap_socket(raw, server_hostname=host)

    req = f"GET {path} HTTP/1.1\r\nHost: {host}\r\nUser-Agent: Mozilla/5.0\r\nConnection: close\r\n\r\n"
    s.send(req.encode())

    data = b""
    while True:
        try:
            chunk = s.recv(8192)
            if not chunk:
                break
            data += chunk
        except socket.timeout:
            break
        except ssl.SSLError:
            break

    s.close()

    # Parse HTTP response
    header_end = data.find(b"\r\n\r\n")
    if header_end == -1:
        return None, data
    headers = data[:header_end].decode("utf-8", errors="ignore")
    body = data[header_end + 4:]

    status_line = headers.split("\r\n")[0]
    status_code = int(status_line.split(" ")[1]) if " " in status_line else 0

    return status_code, body


def test(name, host, path, timeout=15):
    print(f"\n{'='*55}")
    print(f"  {name}")
    print(f"  https://{host}{path[:60]}")
    try:
        t0 = time.time()
        status, body = https_get(host, path, timeout)
        dt = time.time() - t0
        print(f"  ✅ {status} | {len(body)} bytes | {dt:.1f}s")

        if body:
            try:
                d = json.loads(body)
                if isinstance(d, dict):
                    keys = list(d.keys())[:6]
                    print(f"  JSON keys: {keys}")
                elif isinstance(d, bool):
                    print(f"  JSON: {d}")
            except:
                txt = body.decode("utf-8", errors="ignore")[:150]
                if "<" in txt:
                    found = [kw for kw in ["oil-drop","CityRhythm","Leaflet","particles","Iconify"]
                             if kw.lower() in body.decode("utf-8",errors="ignore").lower()]
                    print(f"  HTML {len(body)} chars, found: {found}")
                else:
                    print(f"  Body: {txt[:100]}")
        return True
    except Exception as e:
        print(f"  ❌ {e}")
        return False


print("=" * 55)
print("  API TEST via SOCKS5 46.183.30.125:14520")
print("=" * 55)

r = {}

# CF Worker endpoints
r["CF /map"] = test("CF Worker — Map",
    "anthropic-proxy.uiredepositionherzo.workers.dev", "/map")

r["CF /info"] = test("CF Worker — Info",
    "anthropic-proxy.uiredepositionherzo.workers.dev", "/info")

r["CF firebase"] = test("CF → Firebase complaints",
    "anthropic-proxy.uiredepositionherzo.workers.dev", "/firebase/complaints.json")

r["CF opendata"] = test("CF → Firebase opendata",
    "anthropic-proxy.uiredepositionherzo.workers.dev", "/firebase/opendata_infographic.json")

# Firebase direct
r["Firebase"] = test("Firebase RTDB direct",
    "soobshio-default-rtdb.europe-west1.firebasedatabase.app", "/.json?shallow=true")

# Telegram
r["Telegram"] = test("Telegram API",
    "api.telegram.org", "/bot8535229948:AAF5nvKxCU7nDpbimunheAP9eWRTC8R1R0g/getMe")

# VK
r["VK"] = test("VK API",
    "api.vk.com", "/method/wall.get?owner_id=-35704350&count=1&v=5.199&access_token=90aa91e090aa91e090aa91e02e93944691990aa90aa91e0f927df1cd78c4f4703ae4f3a")

# Open-Meteo
r["Weather"] = test("Open-Meteo",
    "api.open-meteo.com", "/v1/forecast?latitude=60.93&longitude=76.55&current=temperature_2m")

# Summary
print(f"\n{'='*55}")
print("  RESULTS")
print(f"{'='*55}")
ok = sum(1 for v in r.values() if v)
for name, status in r.items():
    print(f"  [{'✅' if status else '❌'}] {name}")
print(f"\n  Total: {ok}/{len(r)} OK")
