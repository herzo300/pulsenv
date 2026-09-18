"""Helpers for city camera HLS URLs: normalization, probing and proxying."""

from __future__ import annotations

import time
from urllib.parse import parse_qs, quote, unquote, urljoin, urlparse

import httpx

PROBE_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
ALLOWED_STREAM_HOSTS = ("pride-net.ru", "dantser.org")


def normalize_camera_stream_url(stream_url: str) -> str:
    normalized = (stream_url or "").strip()
    if not normalized:
        return ""
    if "pride-net.ru" in normalized.lower() and ".m3u8" not in normalized.lower():
        return normalized.rstrip("/") + "/index.m3u8"
    return normalized


def upstream_headers_for_url(url: str) -> dict[str, str]:
    headers = {"User-Agent": PROBE_USER_AGENT}
    lower = url.lower()
    if "pride-net.ru" in lower:
        headers["Referer"] = "https://nv86.ru/cam/"
    elif "dantser.org" in lower:
        headers["Referer"] = "https://dantser.ru/camera/nv"
    return headers


def is_allowed_camera_stream_url(url: str) -> bool:
    parsed = urlparse(url.strip())
    return parsed.scheme in {"http", "https"}


PROBE_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
ALLOWED_STREAM_HOSTS = ("pride-net.ru", "dantser.org")
_PERMANENT_HTTP_STATUSES = frozenset({401, 403, 404, 410})
_HLS_CONTENT_TYPES = (
    "application/vnd.apple.mpegurl",
    "application/x-mpegurl",
    "audio/mpegurl",
    "application/mpegurl",
)


def _response_looks_like_hls(response: httpx.Response, normalized: str) -> bool:
    if response.status_code not in {200, 206}:
        return False
    content_type = (response.headers.get("content-type") or "").lower()
    if any(token in content_type for token in _HLS_CONTENT_TYPES):
        return True
    body_prefix = (response.text or "")[:4096].upper()
    return "#EXTM3U" in body_prefix or ".M3U8" in normalized.upper()


def probe_camera_stream_url(
    url: str,
    *,
    timeout_seconds: float = 8.0,
    retries: int = 2,
) -> tuple[bool, int | None, str, str]:
    """Return (streamable, http_status, error, normalized_url)."""
    normalized = normalize_camera_stream_url(url)
    if not normalized:
        return False, None, "empty url", normalized

    headers = upstream_headers_for_url(normalized)
    last_error = ""
    last_status: int | None = None
    attempts = max(1, int(retries))

    for attempt in range(attempts):
        try:
            with httpx.Client(
                follow_redirects=True,
                timeout=timeout_seconds,
                headers=headers,
                verify=False,
            ) as client:
                response = client.get(normalized)
            last_status = response.status_code
            ok = _response_looks_like_hls(response, normalized)
            if ok:
                return True, last_status, "", normalized
            if last_status in _PERMANENT_HTTP_STATUSES:
                return False, last_status, "", normalized
            last_error = f"http {last_status}"
        except Exception as error:
            last_error = str(error)[:500]

        if attempt < attempts - 1:
            time.sleep(0.35)

    return False, last_status, last_error, normalized


def rewrite_m3u8_playlist(body: str, *, base_url: str, proxy_base: str) -> str:
    lines: list[str] = []
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            lines.append(line)
            continue
        absolute = urljoin(base_url, stripped)
        if is_allowed_camera_stream_url(absolute):
            lines.append(f"{proxy_base}?url={quote(absolute, safe='')}")
        else:
            lines.append(line)
    return "\n".join(lines).rstrip() + "\n"


def decode_proxy_target(url: str) -> str:
    return unquote((url or "").strip())


def resolve_camera_stream_url(url: str) -> str:
    """Unwrap backend proxy URLs and normalize stream address."""
    raw = (url or "").strip()
    if not raw:
        return ""
    parsed = urlparse(raw)
    path = (parsed.path or "").lower()
    if "/cameras/proxy" in path or path.endswith("/proxy"):
        inner_vals = parse_qs(parsed.query).get("url") or []
        inner = decode_proxy_target(inner_vals[0]) if inner_vals else ""
        if inner:
            raw = inner
    return normalize_camera_stream_url(raw)
