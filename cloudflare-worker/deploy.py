#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Деплой Cloudflare Worker через wrangler CLI
Требуется: npm install -g wrangler
Авторизация: wrangler login
"""

import os
import subprocess
import sys
from pathlib import Path

def run_cmd(cmd, check=True):
    """Выполнить команду"""
    print(f"> {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"ERROR: {result.stderr}")
        sys.exit(1)
    return result

def main():
    print("=" * 60)
    print("  ДЕПЛОЙ CLOUDFLARE WORKER")
    print("=" * 60)
    
    worker_dir = Path(__file__).parent
    os.chdir(worker_dir)
    
    # 1. Сборка
    print("\n[1/2] Building worker...")
    # Используем py для Windows, python3 для Linux/Mac
    import platform
    python_cmd = "py" if platform.system() == "Windows" else "python3"
    run_cmd(f"{python_cmd} build_worker.py")
    
    # 2. Проверка wrangler
    print("\n[2/2] Проверка wrangler...")
    result = run_cmd("wrangler --version", check=False)
    if result.returncode != 0:
        print("\n[ERROR] wrangler not found!")
        print("\nInstall wrangler:")
        print("  npm install -g wrangler")
        print("\nLogin:")
        print("  wrangler login")
        sys.exit(1)
    
    print(f"[OK] wrangler {result.stdout.strip()}")
    
    # 3. Деплой
    print("\n[3/3] Деплой worker...")
    run_cmd("wrangler deploy")
    
    print("\n" + "=" * 60)
    print("  [OK] DEPLOY COMPLETE")
    print("=" * 60)
    print("\nURL: https://anthropic-proxy.uiredepositionherzo.workers.dev")
    print("\nCheck:")
    print("  curl https://anthropic-proxy.uiredepositionherzo.workers.dev/health")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[STOP] Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR]: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
