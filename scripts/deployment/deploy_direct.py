#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Прямой деплой Cloudflare Worker через API (без wrangler)
Альтернатива когда wrangler CLI недоступен или GitHub Actions падает
"""

import os
import sys
import json
import requests
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
WORKER_DIR = ROOT / "cloudflare-worker"
WORKER_FILE = WORKER_DIR / "worker.js"

def load_env():
    """Загрузить переменные окружения из .env"""
    env_file = ROOT / ".env"
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    os.environ[key.strip()] = value.strip().strip('"').strip("'")

def get_token_from_wrangler_config():
    """Получить токен из wrangler config"""
    import platform
    if platform.system() == "Windows":
        config_path = Path(os.environ.get("APPDATA", "")) / "xdg.config" / ".wrangler" / "config" / "default.toml"
    else:
        config_path = Path.home() / ".config" / ".wrangler" / "config" / "default.toml"
    
    if config_path.exists():
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                content = f.read()
            for line in content.split('\n'):
                line = line.strip()
                if line.startswith('oauth_token') or line.startswith('api_token'):
                    # Извлекаем значение из кавычек
                    if '"' in line:
                        token = line.split('"')[1]
                    elif "'" in line:
                        token = line.split("'")[1]
                    else:
                        token = line.split("=", 1)[1].strip()
                    return token
        except Exception as e:
            print(f"⚠️  Could not read wrangler config: {e}")
    return None

def deploy_via_api():
    """Деплой worker через Cloudflare API"""
    
    # Загружаем переменные окружения
    load_env()
    
    account_id = os.getenv("CF_ACCOUNT_ID", "b55123fb7c25f3c5f38a1dcab5a36fa8")
    worker_name = os.getenv("CF_WORKER_NAME", "anthropic-proxy")
    api_token = os.getenv("CF_API_TOKEN")
    
    # Пробуем получить токен из wrangler config если не найден в .env
    if not api_token:
        print("🔍 CF_API_TOKEN not found in .env, trying wrangler config...")
        api_token = get_token_from_wrangler_config()
        if api_token:
            print(f"✅ Found token in wrangler config: {api_token[:20]}...")
        else:
            print("❌ ERROR: CF_API_TOKEN not found")
            print("\nВарианты решения:")
            print("1. Добавьте в .env: CF_API_TOKEN=your_token_here")
            print("2. Выполните: wrangler login")
            print("3. Получите токен: https://dash.cloudflare.com/profile/api-tokens")
            return False
    
    # Проверяем наличие worker.js
    if not WORKER_FILE.exists():
        print(f"❌ ERROR: {WORKER_FILE} not found")
        return False
    
    # Читаем worker.js
    print(f"📖 Reading {WORKER_FILE}...")
    with open(WORKER_FILE, "r", encoding="utf-8") as f:
        script = f.read()
    
    file_size = len(script)
    print(f"📊 Worker size: {file_size:,} bytes ({file_size / 1024:.1f} KB)")
    
    if file_size > 10 * 1024 * 1024:
        print("⚠️  WARNING: Worker exceeds 10MB limit!")
        return False
    
    # Загружаем через API
    url = f"https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{worker_name}"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/javascript"
    }
    
    print(f"\n🚀 Deploying {worker_name} to Cloudflare...")
    print(f"   Account ID: {account_id}")
    print(f"   URL: {url}")
    
    try:
        response = requests.put(url, headers=headers, data=script, timeout=60)
        response.raise_for_status()
        
        result = response.json()
        
        if result.get("success"):
            print("\n✅ Deploy successful!")
            print(f"\n🌐 Worker URL: https://{worker_name}.uiredepositionherzo.workers.dev")
            print(f"   Health: https://{worker_name}.uiredepositionherzo.workers.dev/health")
            return True
        else:
            print(f"\n❌ Deploy failed!")
            errors = result.get("errors", [])
            for error in errors:
                print(f"   Error: {error}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"\n❌ Request failed: {e}")
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                print(f"   Response: {json.dumps(error_data, indent=2)}")
            except:
                print(f"   Response: {e.response.text}")
        return False
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("=" * 60)
    print("  ПРЯМОЙ ДЕПЛОЙ CLOUDFLARE WORKER (через API)")
    print("=" * 60)
    print()
    
    # Переходим в директорию worker
    os.chdir(WORKER_DIR)
    
    # Собираем worker.js если нужно
    build_script = WORKER_DIR / "build_worker.py"
    if build_script.exists():
        print("🔨 Building worker.js...")
        import subprocess
        python_cmd = "py" if sys.platform == "win32" else "python3"
        result = subprocess.run([python_cmd, str(build_script)], cwd=WORKER_DIR)
        if result.returncode != 0:
            print("❌ Build failed!")
            return 1
        print("✅ Build complete\n")
    
    # Деплой
    success = deploy_via_api()
    
    if success:
        print("\n" + "=" * 60)
        print("  ✅ DEPLOY COMPLETE")
        print("=" * 60)
        return 0
    else:
        print("\n" + "=" * 60)
        print("  ❌ DEPLOY FAILED")
        print("=" * 60)
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
