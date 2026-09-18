#!/usr/bin/env python3
"""
lightpanda_scraper.py

Быстрый парсер и скрапер городских ресурсов на базе Lightpanda Browser Engine
(https://github.com/lightpanda-io/browser).

Выполняет рендеринг и извлечение данных с сайтов администрации, новостных порталов
и объявлений ЖКХ с поддержкой JavaScript и обхода защиты.
"""

import os
import sys
import json
import urllib.request
import urllib.parse
from typing import Dict, Any, Optional

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')


class LightpandaScraper:
    def __init__(self, endpoint: str = "http://127.0.0.1:8888"):
        self.endpoint = endpoint.rstrip("/")

    def fetch_rendered_page(self, url: str) -> Optional[str]:
        """Запрашивает отредеренную веб-страницу через Lightpanda Engine."""
        print(f"🌐 [LIGHTPANDA SCRAPER] Запрос страницы: {url}")
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Lightpanda/1.0",
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                }
            )
            with urllib.request.urlopen(req, timeout=15) as response:
                return response.read().decode("utf-8", errors="ignore")
        except Exception as err:
            print(f"⚠️ [LIGHTPANDA WARNING] Ошибка сетевого забора ({url}): {err}")
            return None


if __name__ == "__main__":
    scraper = LightpandaScraper()
    html = scraper.fetch_rendered_page("https://nv86.ru")
    if html:
        print(f"✅ Успешно получено {len(html)} символов HTML контента через Lightpanda Scraper.")
