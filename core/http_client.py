# core/http_client.py
"""
Общий HTTP клиент с поддержкой SOCKS5 прокси.
Все сервисы должны использовать get_http_client() вместо httpx.AsyncClient().
"""
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

_PROXY_HOST = os.getenv("PROXY_HOST", "")
_PROXY_PORT = os.getenv("PROXY_PORT", "")
_PROXY_USER = os.getenv("PROXY_USER", "")
_PROXY_PASS = os.getenv("PROXY_PASS", "")

# Формируем SOCKS5 URL
SOCKS5_URL = None
if _PROXY_HOST and _PROXY_PORT:
    if _PROXY_USER and _PROXY_PASS:
        SOCKS5_URL = f"socks5://{_PROXY_USER}:{_PROXY_PASS}@{_PROXY_HOST}:{_PROXY_PORT}"
    else:
        SOCKS5_URL = f"socks5://{_PROXY_HOST}:{_PROXY_PORT}"


def get_http_client(timeout: float = 30.0, **kwargs) -> httpx.AsyncClient:
    """Создаёт AsyncClient с SOCKS5 прокси (если настроен)."""
    if SOCKS5_URL:
        kwargs.setdefault("proxy", SOCKS5_URL)
    return httpx.AsyncClient(timeout=timeout, **kwargs)


def get_sync_client(timeout: float = 30.0, **kwargs) -> httpx.Client:
    """Создаёт синхронный Client с SOCKS5 прокси."""
    if SOCKS5_URL:
        kwargs.setdefault("proxy", SOCKS5_URL)
    return httpx.Client(timeout=timeout, **kwargs)
