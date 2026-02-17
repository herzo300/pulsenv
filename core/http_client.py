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
_PROXY_URL = os.getenv("PROXY_URL", "")

def _socks_supported() -> bool:
    """
    httpx uses the `socksio` extra for SOCKS proxies.
    If it's not installed, passing a socks5:// proxy will crash requests.
    """
    try:
        import socksio  # type: ignore
        return True
    except Exception:
        return False


def _get_proxy_url() -> str | None:
    """
    Prefer explicit PROXY_URL (http/https) if provided.
    Fallback to SOCKS5 constructed from PROXY_* only when socks support exists.
    """
    if _PROXY_URL:
        return _PROXY_URL

    if _PROXY_HOST and _PROXY_PORT and _socks_supported():
        if _PROXY_USER and _PROXY_PASS:
            return f"socks5://{_PROXY_USER}:{_PROXY_PASS}@{_PROXY_HOST}:{_PROXY_PORT}"
        return f"socks5://{_PROXY_HOST}:{_PROXY_PORT}"

    return None


def get_http_client(timeout: float = 30.0, **kwargs) -> httpx.AsyncClient:
    """Создаёт AsyncClient с SOCKS5 прокси (если настроен)."""
    proxy_url = _get_proxy_url()
    if proxy_url:
        kwargs.setdefault("proxy", proxy_url)
    return httpx.AsyncClient(timeout=timeout, **kwargs)


def get_sync_client(timeout: float = 30.0, **kwargs) -> httpx.Client:
    """Создаёт синхронный Client с SOCKS5 прокси."""
    proxy_url = _get_proxy_url()
    if proxy_url:
        kwargs.setdefault("proxy", proxy_url)
    return httpx.Client(timeout=timeout, **kwargs)
