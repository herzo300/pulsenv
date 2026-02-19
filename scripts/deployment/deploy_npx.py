#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Деплой через npx wrangler (без глобальной установки)
Альтернатива когда wrangler не установлен глобально
"""

import os
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
WORKER_DIR = ROOT / "cloudflare-worker"

def main():
    print("=" * 60)
    print("  ДЕПЛОЙ ЧЕРЕЗ NPX WRANGLER")
    print("=" * 60)
    print()
    
    # Переходим в директорию worker
    os.chdir(WORKER_DIR)
    
    # Собираем worker.js если нужно
    build_script = WORKER_DIR / "build_worker.py"
    if build_script.exists():
        print("🔨 Building worker.js...")
        python_cmd = "py" if sys.platform == "win32" else "python3"
        result = subprocess.run([python_cmd, str(build_script)], cwd=WORKER_DIR)
        if result.returncode != 0:
            print("❌ Build failed!")
            return 1
        print("✅ Build complete\n")
    
    # Проверяем наличие npm/node
    print("🔍 Checking npm...")
    try:
        result = subprocess.run(["npm", "--version"], capture_output=True, text=True)
        if result.returncode != 0:
            print("❌ npm not found! Install Node.js first.")
            return 1
        print(f"✅ npm {result.stdout.strip()}\n")
    except FileNotFoundError:
        print("❌ npm not found! Install Node.js first.")
        return 1
    
    # Деплой через npx
    print("🚀 Deploying via npx wrangler...")
    
    # Загружаем переменные окружения
    env_file = ROOT / ".env"
    env = os.environ.copy()
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    env[key.strip()] = value.strip().strip('"').strip("'")
    
    # Используем npx wrangler deploy
    cmd = ["npx", "--yes", "wrangler@latest", "deploy"]
    
    print(f"> {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=WORKER_DIR, env=env)
    
    if result.returncode == 0:
        print("\n✅ Deploy successful!")
        print(f"\n🌐 Worker URL: https://anthropic-proxy.uiredepositionherzo.workers.dev")
        return 0
    else:
        print("\n❌ Deploy failed!")
        print("\n💡 Альтернативы:")
        print("   1. py scripts/deployment/deploy_direct.py (через API)")
        print("   2. Ручной деплой через Cloudflare Dashboard")
        print("   3. npm install -g wrangler && wrangler deploy")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n[STOP] Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR]: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
