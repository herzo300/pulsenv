import asyncio
import logging
from datetime import date
from collections import defaultdict
from playwright.async_api import async_playwright

logger = logging.getLogger(__name__)

class VIPQuotaManager:
    """Управляет лимитами VIP ИИ-Агента (например, 3 задачи в день на пользователя)."""
    def __init__(self, limit: int = 3):
        self.limit = limit
        self._usage = defaultdict(lambda: {"count": 0, "date": date.today()})

    def can_run(self, user_id: str) -> bool:
        record = self._usage[user_id]
        if record["date"] != date.today():
            record["count"] = 0
            record["date"] = date.today()
        
        if record["count"] >= self.limit:
            return False
            
        record["count"] += 1
        return True

quota_manager = VIPQuotaManager(limit=3)

async def analyze_market_price(url: str, user_id: str = "vip_default") -> dict:
    """
    VIP ИИ-Агент: Анализ рыночной стоимости.
    Лимит: 3 раза в день на пользователя.
    """
    if not quota_manager.can_run(user_id):
        return {"status": "error", "message": f"Лимит исчерпан: доступно {quota_manager.limit} задачи глубокого анализа в день."}
        
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
            await page.goto(url, wait_until="domcontentloaded", timeout=15000)
            
            try:
                price_element = await page.wait_for_selector(
                    "text=/\\d{1,3}(?:\\s\\d{3})*\\s*₽/", timeout=5000
                )
                price_text = await price_element.inner_text() if price_element else "Цена не найдена"
            except Exception:
                price_text = "Заблокировано защитой (Captcha) или нет в наличии"
                
            title_element = await page.query_selector("h1")
            title_text = await title_element.inner_text() if title_element else "Без названия"

            await browser.close()
            
            return {
                "status": "success",
                "title": title_text,
                "price": price_text,
                "url": url
            }
    except Exception as e:
        logger.error(f"Error parsing {url}: {e}")
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    # Тестовый запуск
    async def run_test():
        url = "https://www.ozon.ru/category/smartfony-15502/"
        print(f"Парсинг {url}...")
        res = await parse_price(url, "user_vip_1")
        print(res)
    
    asyncio.run(run_test())
