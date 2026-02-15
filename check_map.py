"""Проверяем содержимое карты на CF Worker"""
import socket, ssl, struct

def socks5_get(host, path):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(15)
    s.connect(("46.183.30.125", 14520))
    s.send(b"\x05\x01\x02")
    s.recv(2)
    s.send(b"\x01\x0auser360810\x060dkmyj")
    s.recv(2)
    req = b"\x05\x01\x00\x03" + bytes([len(host)]) + host.encode() + struct.pack("!H", 443)
    s.send(req)
    s.recv(10)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    ss = ctx.wrap_socket(s, server_hostname=host)
    ss.send(f"GET {path} HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n".encode())
    data = b""
    while True:
        try:
            chunk = ss.recv(16384)
            if not chunk: break
            data += chunk
        except: break
    ss.close()
    body = data.split(b"\r\n\r\n", 1)[1] if b"\r\n\r\n" in data else data
    return body.decode("utf-8", errors="ignore")

host = "anthropic-proxy.uiredepositionherzo.workers.dev"

print("=== Checking /map ===")
html = socks5_get(host, "/map")
print(f"Size: {len(html)} chars")

checks = [
    "oil-drop", "CityRhythm", "renderMarkers", "initMap",
    "submitComplaint", "initFilters", "showSplash",
    "leaflet", "anime", "particles", "iconify", "<script>"
]
for kw in checks:
    found = kw.lower() in html.lower()
    icon = "OK" if found else "MISSING"
    print(f"  [{icon}] {kw}")

print(f"\nLast 100 chars: ...{html[-100:]}")

print("\n=== Checking /info ===")
info = socks5_get(host, "/info")
print(f"Size: {len(info)} chars")

checks2 = ["CityPulse", "renderApp", "loadData", "loadWeather", "chart.js", "<script>"]
for kw in checks2:
    found = kw.lower() in info.lower()
    icon = "OK" if found else "MISSING"
    print(f"  [{icon}] {kw}")
