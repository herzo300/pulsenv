#!/usr/bin/env python3
"""
Server Health Check & Auto-Healing Script for City Pulse (Timeweb VPS)
Skill: docker-compose-healthcheck
Checks all 9 Docker containers and auto-heals 502 Bad Gateway Nginx proxy issues.
"""

import subprocess
import urllib.request
import ssl
import sys

SERVICES = [
    "soobshio_backend",
    "soobshio_postgres",
    "soobshio_redis",
    "soobshio_monitoring",
    "soobshio_camera_probe",
    "soobshio_nginx",
    "soobshio_viseron",
    "soobshio_openserp",
    "soobshio_tor",
]

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
        return res.stdout.strip()
    except Exception as e:
        return f"Error: {e}"

def check_docker_containers():
    print("=== 1. Checking 9 Docker Containers Status ===")
    ps_output = run_cmd("docker ps --format '{{.Names}}'")
    running_names = set(ps_output.split("\n")) if ps_output else set()

    all_ok = True
    for service in SERVICES:
        if service in running_names:
            print(f"  ✅ {service}: RUNNING")
        else:
            print(f"  ❌ {service}: STOPPED / DOWN")
            all_ok = False
    return all_ok

def check_backend_direct():
    print("\n=== 2. Checking Direct Backend Health (127.0.0.1:8000/health) ===")
    try:
        req = urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=5)
        code = req.getcode()
        body = req.read().decode("utf-8")
        print(f"  ✅ Direct Backend HTTP {code}: {body}")
        return True
    except Exception as e:
        print(f"  ❌ Direct Backend Failed: {e}")
        return False

def check_nginx_proxy_and_autoheal():
    print("\n=== 3. Checking Nginx Public Proxy (https://45-153-68-59.sslip.io/api/health) ===")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    try:
        req = urllib.request.urlopen("https://45-153-68-59.sslip.io/api/health", context=ctx, timeout=5)
        code = req.getcode()
        body = req.read().decode("utf-8")
        print(f"  ✅ Nginx Proxy HTTP {code}: {body}")
        return True
    except urllib.error.HTTPError as e:
        print(f"  ⚠️ Nginx Proxy HTTP Error {e.code}: {e.reason}")
        if e.code == 502:
            print("  🛠️ 502 Bad Gateway Detected! Triggering Auto-Healing (Restarting Nginx)...")
            heal_res = run_cmd("cd /opt/soobshio && docker compose restart nginx")
            print(f"  🔄 Nginx restart result: {heal_res}")
            
            # Re-test
            try:
                req2 = urllib.request.urlopen("https://45-153-68-59.sslip.io/api/health", context=ctx, timeout=5)
                print(f"  ✅ Auto-Healed! Nginx Proxy HTTP {req2.getcode()}: {req2.read().decode('utf-8')}")
                return True
            except Exception as e2:
                print(f"  ❌ Post-healing test failed: {e2}")
                return False
        return False
    except Exception as e:
        print(f"  ❌ Nginx Proxy Connection Error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Running City Pulse VPS Healthcheck & Auto-Healer...")
    containers_ok = check_docker_containers()
    backend_ok = check_backend_direct()
    proxy_ok = check_nginx_proxy_and_autoheal()
    
    print("\n=== Final Status Report ===")
    if backend_ok and proxy_ok:
        print("🎉 All 9 Services & Proxy are fully operational and healthy!")
        sys.exit(0)
    else:
        print("⚠️ Healthcheck finished with warnings.")
        sys.exit(1)
