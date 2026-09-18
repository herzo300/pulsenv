"""Telegram client factory with MTProxy / SOCKS support for monitoring."""

from __future__ import annotations

import os

from telethon import TelegramClient

from .config import API_HASH, API_ID


def _proxy_url() -> str | None:
    for key in ("TELEGRAM_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        value = (os.getenv(key) or "").strip()
        if value:
            return value
    return None


def _telethon_proxy() -> tuple | None:
    proxy = _proxy_url()
    if not proxy:
        return None
    from urllib.parse import urlparse

    import socks

    parsed = urlparse(proxy)
    scheme = (parsed.scheme or "socks5").lower()
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (1080 if "socks" in scheme else 8080)
    mapping = {
        "socks5": socks.SOCKS5,
        "socks4": socks.SOCKS4,
        "http": socks.HTTP,
        "https": socks.HTTP,
    }
    sock_type = mapping.get(scheme, socks.SOCKS5)
    username = parsed.username
    password = parsed.password
    if username or password:
        return (sock_type, host, port, True, username, password)
    return (sock_type, host, port)


def _mtproxy_config() -> tuple[type, tuple] | None:
    raw = (os.getenv("TELEGRAM_MTPROXY") or "").strip()
    if not raw:
        return None
    from telethon import connection

    parts = raw.split(":", 2)
    if len(parts) < 3:
        raise ValueError("TELEGRAM_MTPROXY must be host:port:hexsecret")
    host = parts[0]
    port = int(parts[1])
    secret_str = parts[2]

    return (
        connection.ConnectionTcpMTProxyRandomizedIntermediate,
        (host, port, secret_str),
    )


def build_monitoring_telegram_client(session_path: str) -> TelegramClient:
    mtproxy = _mtproxy_config()
    if mtproxy:
        conn_type, proxy = mtproxy
        return TelegramClient(
            session_path,
            API_ID,
            API_HASH,
            connection=conn_type,
            proxy=proxy,
        )
    return TelegramClient(
        session_path,
        API_ID,
        API_HASH,
        proxy=_telethon_proxy(),
    )


def describe_telegram_transport() -> str:
    if (os.getenv("TELEGRAM_MTPROXY") or "").strip():
        host, port, *_ = (os.getenv("TELEGRAM_MTPROXY") or "").split(":", 2)
        return f"MTProxy {host}:{port}"
    proxy = _proxy_url()
    if proxy:
        return f"proxy {proxy}"
    return "direct"
