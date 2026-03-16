import os
import json
import time
import random
import urllib.request
from urllib.error import URLError, HTTPError
import ssl

# Отключаем проверку SSL для "грязных" прокси
ssl._create_default_https_context = ssl._create_unverified_context

# ==========================================
# 🛑 STEALTH & SECURITY SETTINGS (ЗАЩИТА)
# ==========================================
# Впишите сюда адреса купленных прокси (IPv4), чтобы Геопортал видел разные IP
PROXIES = [
    # "http://user:pass@12.34.56.78:8000",
    # "http://user:pass@87.65.43.21:8000",
]

# Случайная пауза между скачиваниями (имитация долгого чтения человеком)
DELAY_RANGE = (5.0, 18.0) 

# Лимит файлов за 1 запуск (чтобы не привлекать внимание, скачиваем порциями)
# Настройте планировщик задач Windows запускать скрипт раз в день.
MAX_FILES_PER_RUN = 500       

# Ротация юзер-агентов (имитация разных браузеров и ОС)
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64; rv:123.0) Gecko/20100101 Firefox/123.0"
]

# ==========================================
# ☁️ SUPABASE DIRECT UPLOAD SETTINGS
# ==========================================
# Данные не касаются диска, летят сквозь RAM прямо в ваше облако.
SUPABASE_URL = "https://[ВАШ_ПРОЕКТ].supabase.co"
SUPABASE_SERVICE_KEY = "[ВАШ_СЕКРЕТНЫЙ_SERVICE_ROLE_KEY]"
BUCKET_NAME = "3dtiles"
SUPABASE_FOLDER = "nv_2025"

BASE_URL = "https://geoportal.n-vartovsk.ru/tls/1/1114"
STATE_FILE = "stealth_state.json"

# ==========================================

class StealthDownloader:
    def __init__(self):
        self.downloaded = set()
        self.queue = set()
        self.files_downloaded_today = 0
        self.load_state()

        if not self.queue:
            # Инициализация первого корня
            self.queue.add("tileset.json")

    def load_state(self):
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, 'r') as f:
                    state = json.load(f)
                    self.downloaded = set(state.get('downloaded', []))
                    self.queue = set(state.get('queue', []))
            except Exception:
                pass

    def save_state(self):
        with open(STATE_FILE, 'w') as f:
            json.dump({
                'downloaded': list(self.downloaded),
                'queue': list(self.queue)
            }, f, indent=4)

    def get_opener(self):
        handlers = []
        if PROXIES:
            proxy = random.choice(PROXIES)
            handlers.append(urllib.request.ProxyHandler({'http': proxy, 'https': proxy}))
        
        return urllib.request.build_opener(*handlers)

    def upload_to_supabase(self, rel_path, data):
        """Прямая загрузка байтов в Supabase Storage API минуя SSD"""
        endpoint = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{SUPABASE_FOLDER}/{rel_path}"
        
        req = urllib.request.Request(endpoint, data=data, method='POST')
        req.add_header('Authorization', f'Bearer {SUPABASE_SERVICE_KEY}')
        req.add_header('Content-Type', 'application/octet-stream')
        # Игнорируем ошибку, если вдруг файл уже есть
        req.add_header('x-upsert', 'true') 
        
        try:
            with urllib.request.urlopen(req) as response:
                return response.status in [200, 201]
        except HTTPError as e:
            print(f"[Supabase] HTTP Error: {e.code} for {rel_path}")
            return False
        except Exception as e:
            print(f"[Supabase] Upload Failed: {e}")
            return False

    def download_in_memory(self, rel_path):
        target_url = f"{BASE_URL}/{rel_path}"
        
        req = urllib.request.Request(
            target_url, 
            headers={'User-Agent': random.choice(USER_AGENTS)}
        )
        
        opener = self.get_opener()
        try:
            with opener.open(req, timeout=30) as response:
                return response.read()
        except Exception as e:
            print(f"[Geoportal] Fetch error for {rel_path}: {e}")
            return None

    def parse_tileset_for_links(self, json_data, current_dir):
        try:
            tileset = json.loads(json_data.decode('utf-8'))
        except:
            return

        def extract_uris(node):
            node_current = node.get('content', {})
            uri = node_current.get('uri') or node_current.get('url')
            if uri:
                # Если путь относительный корню или папке
                full_rel = f"{current_dir}/{uri}" if current_dir else uri
                if full_rel not in self.downloaded:
                    self.queue.add(full_rel)
            
            for content in node.get('contents', []):
                uri = content.get('uri') or content.get('url')
                if uri:
                    full_rel = f"{current_dir}/{uri}" if current_dir else uri
                    if full_rel not in self.downloaded:
                        self.queue.add(full_rel)

            for child in node.get('children', []):
                extract_uris(child)

        if 'root' in tileset:
            extract_uris(tileset['root'])

    def run(self):
        print(f"🕵️  STEALTH MODE ACTIVATED. Limit: {MAX_FILES_PER_RUN} files.")
        
        while self.queue and self.files_downloaded_today < MAX_FILES_PER_RUN:
            rel_path = self.queue.pop()
            
            if rel_path in self.downloaded:
                continue

            print(f"[{self.files_downloaded_today+1}/{MAX_FILES_PER_RUN}] Stealing: {rel_path}")
            
            # 1. Скрыто качаем в ОЗУ
            data = self.download_in_memory(rel_path)
            if not data:
                # Если ошибка, вернем в очередь
                self.queue.add(rel_path)
                time.sleep(10)
                continue

            # 2. Парсим если это JSON (разворачиваем дерево города)
            if rel_path.endswith('.json'):
                curr_dir = "/".join(rel_path.split('/')[:-1])
                self.parse_tileset_for_links(data, curr_dir)

            # 3. Тихо льем в Ваш Supabase
            uploaded = self.upload_to_supabase(rel_path, data)
            
            if uploaded:
                self.downloaded.add(rel_path)
                self.files_downloaded_today += 1
                self.save_state()
            else:
                self.queue.add(rel_path)

            # 4. Имитация человеческого поведения (Случайная задержка)
            sleep_time = random.uniform(DELAY_RANGE[0], DELAY_RANGE[1])
            print(f"   ✓ Uploaded. Hiding for {sleep_time:.1f}s...")
            time.sleep(sleep_time)

        print("\n🏁 Mission accomplished for today. Saved state.")
        print(f"Total stolen this run: {self.files_downloaded_today}. Remaining in queue: {len(self.queue)}.")

if __name__ == "__main__":
    if "YOUR_PROJECT" in SUPABASE_URL:
        print("❌ EXCEPTION: Впишите ваши Supabase URL и KEY в код скрипта перед раннингом!")
    else:
        scraper = StealthDownloader()
        scraper.run()
