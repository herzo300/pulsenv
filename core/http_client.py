# core/http_client.py
"""
Общий HTTP клиент с поддержкой SOCKS5/HTTP прокси.
Все сервисы должны использовать get_http_client() вместо httpx.AsyncClient().

USE_PROXY_FOR_EXTERNAL=true — использовать прокси для OpenRouter, Firebase, VK (когда прямое соединение недоступно).
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
USE_PROXY_FOR_EXTERNAL = os.getenv("USE_PROXY_FOR_EXTERNAL", "auto").lower() in ("true", "1", "yes")


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


def get_proxy_url() -> str | None:
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


# Специальное значение: не передавать proxy в kwargs, применять логику USE_PROXY_FOR_EXTERNAL
_AUTO_PROXY = object()


def get_http_client(timeout: float = 30.0, proxy: str | None | bool | object = _AUTO_PROXY, **kwargs) -> httpx.AsyncClient:
    """
    Создаёт AsyncClient. Параметр proxy:
    - не передан (по умолчанию): при USE_PROXY_FOR_EXTERNAL=true использовать прокси
    - False или None: явно без прокси
    - True: явно с прокси (если настроен)
    """
    proxy_url = get_proxy_url()
    if "proxy" in kwargs:
        pass  # явно передан в kwargs
    elif proxy is False or proxy is None:
        kwargs["proxy"] = None
    elif proxy is True and proxy_url:
        kwargs["proxy"] = proxy_url
    elif isinstance(proxy, str):
        kwargs["proxy"] = proxy
    elif proxy is _AUTO_PROXY:
        if USE_PROXY_FOR_EXTERNAL and proxy_url:
            kwargs["proxy"] = proxy_url
        else:
            kwargs["proxy"] = None
    elif proxy_url:
        kwargs.setdefault("proxy", proxy_url)
    return httpx.AsyncClient(timeout=timeout, **kwargs)


async def fetch_with_proxy_fallback(method: str, url: str, *, timeout: float = 30.0, try_proxy_first: bool = False, **kwargs):
    """
    Выполняет запрос, при ошибке пробует другой режим (с/без прокси).
    Returns: httpx.Response or None
    """
    proxy_url = get_proxy_url()
    clients = []
    if try_proxy_first and proxy_url:
        clients.append((proxy_url, "с прокси"))
        clients.append((None, "без прокси"))
    else:
        clients.append((None, "без прокси"))
        if proxy_url:
            clients.append((proxy_url, "с прокси"))
    last_err = None
    for px, _ in clients:
        try:
            async with httpx.AsyncClient(timeout=timeout, proxy=px) as c:
                if method.upper() == "GET":
                    return await c.get(url, **kwargs)
                if method.upper() == "POST":
                    return await c.post(url, **kwargs)
                if method.upper() == "PUT":
                    return await c.put(url, **kwargs)
                if method.upper() == "PATCH":
                    return await c.patch(url, **kwargs)
        except Exception as e:
            last_err = e
            continue
    if last_err:
        raise last_err
    return None


def get_sync_client(timeout: float = 30.0, **kwargs) -> httpx.Client:
    """Создаёт синхронный Client с SOCKS5 прокси."""
    proxy_url = get_proxy_url()
    if proxy_url:
        kwargs.setdefault("proxy", proxy_url)
    return httpx.Client(timeout=timeout, **kwargs)
