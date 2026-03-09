"""Runtime and traffic metrics for the admin dashboard."""

from __future__ import annotations

import json
import threading
import time
from collections import Counter, deque
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import Request

ACTIVE_WINDOW_SECONDS = 150
LAST_HOUR_SECONDS = 3600
LAST_DAY_SECONDS = 86400
LAST_WEEK_SECONDS = 7 * LAST_DAY_SECONDS

ROOT = Path(__file__).resolve().parent.parent.parent
STORAGE_PATH = ROOT / "data" / "admin_metrics.json"


def _now_ts() -> float:
    return time.time()


def _isoformat(ts: float | None) -> str | None:
    if ts is None:
        return None
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def extract_client_ip(request: Request) -> str:
    """Best-effort client IP extraction with proxy header support."""
    forwarded = request.headers.get("x-forwarded-for", "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()

    real_ip = request.headers.get("x-real-ip", "").strip()
    if real_ip:
        return real_ip

    return (request.client.host if request.client else "unknown").strip() or "unknown"


class AppMetricsStore:
    """Process-local metrics with light JSON persistence for unique IP totals."""

    def __init__(self, storage_path: Path):
        self._storage_path = storage_path
        self._lock = threading.Lock()
        self._started_at = _now_ts()
        self._total_requests = 0
        self._total_heartbeats = 0
        self._peak_active_ips = 0
        self._last_activity_at: float | None = None
        self._known_ips: set[str] = set()
        self._active_clients: dict[str, dict[str, Any]] = {}
        self._route_counts: Counter[str] = Counter()
        self._request_events: deque[tuple[float, str]] = deque()
        self._heartbeat_events: deque[tuple[float, str]] = deque()
        self._load()

    def _load(self) -> None:
        if not self._storage_path.exists():
            return

        try:
            payload = json.loads(self._storage_path.read_text(encoding="utf-8"))
        except Exception:
            return

        self._known_ips = set(payload.get("known_ips", []))
        self._total_requests = int(payload.get("total_requests", 0))
        self._total_heartbeats = int(payload.get("total_heartbeats", 0))
        self._peak_active_ips = int(payload.get("peak_active_ips", 0))
        self._last_activity_at = payload.get("last_activity_at")
        if self._last_activity_at is not None:
            self._last_activity_at = float(self._last_activity_at)
        self._route_counts.update(payload.get("route_counts", {}))

    def _persist(self) -> None:
        payload = {
            "known_ips": sorted(self._known_ips),
            "total_requests": self._total_requests,
            "total_heartbeats": self._total_heartbeats,
            "peak_active_ips": self._peak_active_ips,
            "last_activity_at": self._last_activity_at,
            "route_counts": dict(self._route_counts),
        }
        self._storage_path.parent.mkdir(parents=True, exist_ok=True)
        self._storage_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _trim_request_events(self, now_ts: float) -> None:
        threshold = now_ts - LAST_WEEK_SECONDS
        while self._request_events and self._request_events[0][0] < threshold:
            self._request_events.popleft()

    def _trim_heartbeat_events(self, now_ts: float) -> None:
        threshold = now_ts - LAST_WEEK_SECONDS
        while self._heartbeat_events and self._heartbeat_events[0][0] < threshold:
            self._heartbeat_events.popleft()

    def _trim_runtime_events(self, now_ts: float) -> None:
        self._trim_request_events(now_ts)
        self._trim_heartbeat_events(now_ts)

    def _prune_active_clients(self, now_ts: float) -> None:
        stale_before = now_ts - ACTIVE_WINDOW_SECONDS
        stale_ips = [
            ip
            for ip, client in self._active_clients.items()
            if float(client.get("last_seen_at", 0)) < stale_before
        ]
        for ip in stale_ips:
            self._active_clients.pop(ip, None)

    def _update_last_activity(self, now_ts: float) -> None:
        self._last_activity_at = now_ts

    def record_request(self, ip: str, path: str) -> None:
        now_ts = _now_ts()
        with self._lock:
            self._total_requests += 1
            self._known_ips.add(ip)
            self._route_counts[path] += 1
            self._request_events.append((now_ts, path))
            self._trim_runtime_events(now_ts)
            self._prune_active_clients(now_ts)
            self._update_last_activity(now_ts)
            if self._total_requests % 20 == 0:
                self._persist()

    def record_heartbeat(
        self,
        *,
        ip: str,
        platform: str | None,
        app_version: str | None,
        screen: str | None,
    ) -> dict[str, Any]:
        now_ts = _now_ts()
        with self._lock:
            existing = self._active_clients.get(ip, {})
            heartbeat_count = int(existing.get("heartbeat_count", 0)) + 1
            self._active_clients[ip] = {
                "first_seen_at": existing.get("first_seen_at", now_ts),
                "last_seen_at": now_ts,
                "platform": (platform or existing.get("platform") or "unknown").strip(),
                "app_version": (
                    app_version or existing.get("app_version") or "unknown"
                ).strip(),
                "screen": (screen or existing.get("screen") or "unknown").strip(),
                "heartbeat_count": heartbeat_count,
            }
            self._total_heartbeats += 1
            self._known_ips.add(ip)
            self._heartbeat_events.append((now_ts, ip))
            self._trim_runtime_events(now_ts)
            self._prune_active_clients(now_ts)
            self._peak_active_ips = max(self._peak_active_ips, len(self._active_clients))
            self._update_last_activity(now_ts)
            self._persist()
            return self._snapshot_locked(now_ts)

    def snapshot(self) -> dict[str, Any]:
        now_ts = _now_ts()
        with self._lock:
            self._trim_runtime_events(now_ts)
            self._prune_active_clients(now_ts)
            return self._snapshot_locked(now_ts)

    def _snapshot_locked(self, now_ts: float) -> dict[str, Any]:
        active_clients = list(self._active_clients.values())
        requests_last_hour = sum(
            1 for event_ts, _ in self._request_events if now_ts - event_ts <= LAST_HOUR_SECONDS
        )
        requests_last_day = sum(
            1 for event_ts, _ in self._request_events if now_ts - event_ts <= LAST_DAY_SECONDS
        )
        requests_last_week = len(self._request_events)
        active_platforms = Counter(client.get("platform", "unknown") for client in active_clients)
        active_versions = Counter(client.get("app_version", "unknown") for client in active_clients)
        active_screens = Counter(client.get("screen", "unknown") for client in active_clients)
        uptime_seconds = max(0, int(now_ts - self._started_at))
        activity_series = {
            "hour": self._build_series_locked(
                now_ts,
                range_seconds=LAST_HOUR_SECONDS,
                bucket_seconds=300,
                label_format="%H:%M",
            ),
            "day": self._build_series_locked(
                now_ts,
                range_seconds=LAST_DAY_SECONDS,
                bucket_seconds=3600,
                label_format="%H:%M",
            ),
            "week": self._build_series_locked(
                now_ts,
                range_seconds=LAST_WEEK_SECONDS,
                bucket_seconds=LAST_DAY_SECONDS,
                label_format="%d.%m",
            ),
        }

        return {
            "active_unique_ips": len(self._active_clients),
            "total_unique_ips": len(self._known_ips),
            "peak_active_unique_ips": self._peak_active_ips,
            "active_window_seconds": ACTIVE_WINDOW_SECONDS,
            "total_requests": self._total_requests,
            "requests_last_hour": requests_last_hour,
            "requests_last_24_hours": requests_last_day,
            "requests_last_7_days": requests_last_week,
            "total_heartbeats": self._total_heartbeats,
            "uptime_seconds": uptime_seconds,
            "uptime_human": _humanize_seconds(uptime_seconds),
            "last_activity_at": _isoformat(self._last_activity_at),
            "active_platforms": dict(active_platforms),
            "active_app_versions": dict(active_versions),
            "active_screens": dict(active_screens),
            "activity_series": activity_series,
            "top_routes": [
                {"path": path, "hits": hits}
                for path, hits in self._route_counts.most_common(7)
            ],
        }

    def _build_series_locked(
        self,
        now_ts: float,
        *,
        range_seconds: int,
        bucket_seconds: int,
        label_format: str,
    ) -> list[dict[str, Any]]:
        bucket_count = max(1, range_seconds // bucket_seconds)
        aligned_end = (int(now_ts) // bucket_seconds) * bucket_seconds + bucket_seconds
        range_start = aligned_end - range_seconds
        buckets: list[dict[str, Any]] = []

        for index in range(bucket_count):
            bucket_start = range_start + index * bucket_seconds
            buckets.append(
                {
                    "label": datetime.fromtimestamp(
                        bucket_start, tz=timezone.utc
                    ).strftime(label_format),
                    "requests": 0,
                    "heartbeats": 0,
                    "unique_ips": set(),
                }
            )

        for event_ts, _path in self._request_events:
            if event_ts < range_start or event_ts >= aligned_end:
                continue
            index = int((event_ts - range_start) // bucket_seconds)
            if 0 <= index < bucket_count:
                buckets[index]["requests"] += 1

        for event_ts, ip in self._heartbeat_events:
            if event_ts < range_start or event_ts >= aligned_end:
                continue
            index = int((event_ts - range_start) // bucket_seconds)
            if 0 <= index < bucket_count:
                buckets[index]["heartbeats"] += 1
                buckets[index]["unique_ips"].add(ip)

        return [
            {
                "label": bucket["label"],
                "requests": bucket["requests"],
                "heartbeats": bucket["heartbeats"],
                "unique_ips": len(bucket["unique_ips"]),
            }
            for bucket in buckets
        ]


def _humanize_seconds(seconds: int) -> str:
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)
    parts: list[str] = []
    if days:
        parts.append(f"{days}d")
    if hours or parts:
        parts.append(f"{hours}h")
    if minutes or parts:
        parts.append(f"{minutes}m")
    parts.append(f"{secs}s")
    return " ".join(parts)


metrics_store = AppMetricsStore(STORAGE_PATH)
