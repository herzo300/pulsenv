#!/usr/bin/env python3
"""
Playwright-парсер камер Нижневартовска с gorod3466.ru и dantser.ru
Запускает headless-браузер, перехватывает HLS-запросы, сохраняет список камер.

Установка:
  pip install playwright
  playwright install chromium
"""

import asyncio
import json
import os
import re
import sys
from pathlib import Path

try:
    from playwright.async_api import async_playwright, Route
except ImportError:
    print("Установи playwright: pip install playwright && playwright install chromium")
    sys.exit(1)

OUTPUT_FILE = Path(__file__).parent / "public" / "cameras_discovered.json"

# Known stream URL patterns
HLS_PATTERNS = [
    r"stream\d*\.dantser\.org/([^/]+)/",
    r"nginx0\d\.pride-net\.ru/([^/]+)/",
    r"video\.pride-net\.ru/([^/]+)/",
]

# Camera name patterns from page text
NAME_PATTERNS = [
    r"(ул\.?\s+[\w\s]+\s*,?\s*\d+)",
    r"(пер\.?\s+[\w\s]+\s*-\s*[\w\s]+)",
    r"(перекресток\s+[\w\s]+-[\w\s]+)",
]


class CameraDiscovery:
    def __init__(self):
        self.cameras = {}  # url → camera data
        self.pending_names = []

    def record_stream(self, url: str, source_page: str = "", cam_name: str = ""):
        """Record a discovered camera stream URL."""
        if url in self.cameras:
            return False

        # Extract slug/id
        slug = None
        provider = None
        for pat in HLS_PATTERNS:
            m = re.search(pat, url)
            if m:
                slug = m.group(1)
                if "dantser" in url:
                    provider = "dantser"
                elif "pride" in url:
                    provider = "pride"
                break

        if not slug:
            return False

        self.cameras[url] = {
            "n": cam_name or slug.replace("_", " "),
            "s": url,
            "provider": provider,
            "slug": slug,
            "source": source_page,
            "discovered": True,
        }
        print(f"  🎥 [{provider}] {slug}")
        return True


async def scrape_dantser(page, discovery: CameraDiscovery):
    """Scrape camera list from dantser.ru/camera/nv"""
    print("\n📡 Scraping dantser.ru/camera/nv ...")

    captured_streams = set()

    async def handle_route(route: Route):
        url = route.request.url
        for pat in HLS_PATTERNS:
            if re.search(pat, url) and ".m3u8" in url:
                captured_streams.add(url)
                discovery.record_stream(url, "dantser.ru/camera/nv")
        await route.continue_()

    await page.route("**/*.m3u8", handle_route)
    await page.route("**/stream*", handle_route)
    await page.route("**/nginx*", handle_route)

    try:
        await page.goto("https://dantser.ru/camera/nv", wait_until="networkidle", timeout=30000)
        await page.wait_for_timeout(3000)

        # Scroll to trigger lazy loading
        for _ in range(5):
            await page.evaluate("window.scrollBy(0, window.innerHeight)")
            await page.wait_for_timeout(1500)

        # Click on each camera card to trigger stream load
        cards = await page.query_selector_all(".camera-card, .cam-item, [class*='camera'], [class*='cam']")
        print(f"  Found {len(cards)} camera elements")

        for i, card in enumerate(cards[:50]):
            try:
                cam_name = await card.inner_text()
                cam_name = cam_name.strip().split("\n")[0][:80]
                await card.click()
                await page.wait_for_timeout(800)
            except Exception:
                pass

    except Exception as e:
        print(f"  Error: {e}")

    # Also intercept from network log
    print(f"  Captured {len(captured_streams)} streams from dantser.ru")
    return captured_streams


async def scrape_pride_via_nv86(page, discovery: CameraDiscovery):
    """Scrape from nv86.ru which aggregates pride cameras."""
    print("\n📡 Scraping pride via nv86.ru/cam ...")

    captured_streams = set()

    async def handle_route(route: Route):
        url = route.request.url
        if any(re.search(p, url) for p in HLS_PATTERNS):
            captured_streams.add(url)
        await route.continue_()

    await page.route("**/*", handle_route)

    try:
        await page.goto("https://nv86.ru/cam/", wait_until="domcontentloaded", timeout=20000)
        await page.wait_for_timeout(2000)

        # Get camera links
        links = await page.query_selector_all("a[href*='cam'], a[href*='camera']")
        cam_urls = set()
        for link in links[:100]:
            href = await link.get_attribute("href")
            if href:
                cam_urls.add(href if href.startswith("http") else f"https://nv86.ru{href}")

        print(f"  Found {len(cam_urls)} camera links")

        for cam_url in list(cam_urls)[:30]:
            try:
                await page.goto(cam_url, wait_until="networkidle", timeout=15000)
                await page.wait_for_timeout(2000)
                # Extract cam name from page
                title = await page.title()
            except Exception:
                pass

    except Exception as e:
        print(f"  Error: {e}")

    # Fallback: intercept pride streams from any page
    for url in captured_streams:
        for pat in HLS_PATTERNS:
            m = re.search(pat, url)
            if m:
                discovery.record_stream(url, "nv86.ru/cam")

    print(f"  Captured {len(captured_streams)} streams from nv86.ru")
    return captured_streams


async def scrape_gorod3466(page, discovery: CameraDiscovery):
    """Scrape cameras from gorod3466.ru."""
    print("\n📡 Scraping gorod3466.ru ...")
    captured = set()

    async def intercept(route: Route):
        url = route.request.url
        if any(re.search(p, url) for p in HLS_PATTERNS):
            captured.add(url)
            discovery.record_stream(url, "gorod3466.ru")
        await route.continue_()

    await page.route("**/*", intercept)

    try:
        await page.goto("https://gorod3466.ru/webcam/", wait_until="networkidle", timeout=20000)
        await page.wait_for_timeout(3000)

        # Try to find camera items
        items = await page.query_selector_all("[class*='webcam'], [class*='camera'], iframe, video")
        print(f"  Found {len(items)} media elements")

        for item in items[:30]:
            try:
                src = await item.get_attribute("src") or ""
                if src and any(re.search(p, src) for p in HLS_PATTERNS):
                    captured.add(src)
            except Exception:
                pass

    except Exception as e:
        print(f"  Error: {e}")

    print(f"  Captured {len(captured)} streams from gorod3466.ru")
    return captured


async def merge_with_existing(new_cameras: dict) -> list:
    """Merge newly discovered cameras with existing cameras_nv_full.json."""
    existing_path = Path(__file__).parent / "public" / "cameras_nv_full.json"
    if existing_path.exists():
        with open(existing_path, "r", encoding="utf-8") as f:
            existing = json.load(f)
        existing_urls = {c["s"] for c in existing}
    else:
        existing = []
        existing_urls = set()

    added = 0
    for url, cam_data in new_cameras.items():
        if url not in existing_urls:
            existing.append(cam_data)
            added += 1

    print(f"\n✅ Added {added} new cameras (total: {len(existing)})")
    return existing


async def main():
    discovery = CameraDiscovery()

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
        )
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            viewport={"width": 1920, "height": 1080},
        )

        page = await context.new_page()

        # Scrape sources in sequence
        await scrape_dantser(page, discovery)
        await scrape_gorod3466(page, discovery)
        await scrape_pride_via_nv86(page, discovery)

        await browser.close()

    print(f"\n📊 Total discovered: {len(discovery.cameras)} unique cameras")

    # Merge with existing
    merged = await merge_with_existing(discovery.cameras)

    # Save results
    OUTPUT_FILE.parent.mkdir(exist_ok=True)

    # Save discovered only
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(list(discovery.cameras.values()), f, ensure_ascii=False, indent=2)
    print(f"💾 Saved to {OUTPUT_FILE}")

    # Update merged file
    if merged:
        merged_path = OUTPUT_FILE.parent / "cameras_nv_full.json"
        with open(merged_path, "w", encoding="utf-8") as f:
            json.dump(merged, f, ensure_ascii=False, indent=2)
        print(f"💾 Updated cameras_nv_full.json → {len(merged)} cameras")

    return list(discovery.cameras.values())


if __name__ == "__main__":
    asyncio.run(main())
