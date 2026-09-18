"""Stats snapshot and time series aggregation for admin dashboard."""

from __future__ import annotations

from collections import Counter
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import desc, func
from sqlalchemy.orm import Session

from services.Backend.admin_metrics.models import (
    AdminAccessPolicy,
    AdminCameraCatalog,
    AdminHeartbeatEvent,
    AdminRequestEvent,
    AdminRuntimeDevice,
)
from services.Backend.admin_metrics.utils import (
    ACTIVE_WINDOW_SECONDS,
    LAST_DAY_SECONDS,
    LAST_HOUR_SECONDS,
    LAST_WEEK_SECONDS,
    _as_utc,
    _humanize_seconds,
    _isoformat,
    _now_ts,
    _utcnow,
)


class AdminRuntimeStoreStatsMixin:
    """Mixin providing dashboard stats snapshot and time series."""

    def _sum_traffic(self, db: Session, threshold: datetime) -> int:
        from services.Backend.admin_metrics.models import AdminRequestEvent

        row = (
            db.query(
                func.coalesce(func.sum(AdminRequestEvent.request_bytes), 0),
                func.coalesce(func.sum(AdminRequestEvent.response_bytes), 0),
            )
            .filter(AdminRequestEvent.happened_at >= threshold)
            .one()
        )
        return int((row[0] or 0) + (row[1] or 0))

    def _build_series(
        self,
        request_events: list[AdminRequestEvent],
        heartbeat_events: list[AdminHeartbeatEvent],
        *,
        range_seconds: int,
        bucket_seconds: int,
        label_format: str,
    ) -> list[dict[str, Any]]:
        now_ts = _now_ts()
        bucket_count = max(1, range_seconds // bucket_seconds)
        aligned_end = (int(now_ts) // bucket_seconds) * bucket_seconds + bucket_seconds
        range_start = aligned_end - range_seconds

        buckets: list[dict[str, Any]] = []
        for index in range(bucket_count):
            bucket_start = range_start + index * bucket_seconds
            buckets.append(
                {
                    "label": datetime.fromtimestamp(
                        bucket_start,
                        tz=UTC,
                    ).strftime(label_format),
                    "requests": 0,
                    "heartbeats": 0,
                    "unique_devices": set(),
                }
            )

        for event in request_events:
            event_ts = event.happened_at.timestamp()
            if event_ts < range_start or event_ts >= aligned_end:
                continue
            bucket_index = int((event_ts - range_start) // bucket_seconds)
            if 0 <= bucket_index < bucket_count:
                buckets[bucket_index]["requests"] += 1

        for event in heartbeat_events:
            event_ts = event.happened_at.timestamp()
            if event_ts < range_start or event_ts >= aligned_end:
                continue
            bucket_index = int((event_ts - range_start) // bucket_seconds)
            if 0 <= bucket_index < bucket_count:
                buckets[bucket_index]["heartbeats"] += 1
                buckets[bucket_index]["unique_devices"].add(event.device_id)

        return [
            {
                "label": bucket["label"],
                "requests": bucket["requests"],
                "heartbeats": bucket["heartbeats"],
                "unique_devices": len(bucket["unique_devices"]),
            }
            for bucket in buckets
        ]

    def snapshot(self) -> dict[str, Any]:
        now = _utcnow()
        active_threshold = now - timedelta(seconds=ACTIVE_WINDOW_SECONDS)
        week_threshold = now - timedelta(seconds=LAST_WEEK_SECONDS)
        day_threshold = now - timedelta(seconds=LAST_DAY_SECONDS)
        hour_threshold = now - timedelta(seconds=LAST_HOUR_SECONDS)

        db = self._db()
        try:
            stats = self._get_or_create_stats(db)
            active_devices = (
                db.query(AdminRuntimeDevice)
                .filter(AdminRuntimeDevice.last_seen_at >= active_threshold)
                .order_by(desc(AdminRuntimeDevice.last_seen_at))
                .all()
            )
            devices = (
                db.query(AdminRuntimeDevice)
                .order_by(desc(AdminRuntimeDevice.last_seen_at))
                .limit(50)
                .all()
            )
            policies = {
                row.device_id: row
                for row in db.query(AdminAccessPolicy).filter(
                    AdminAccessPolicy.device_id.in_(
                        [device.device_id for device in devices] or [""]
                    )
                )
            }
            cameras_total = (
                db.query(func.count(AdminCameraCatalog.camera_id)).scalar() or 0
            )
            source_index = self._camera_source_index()
            cameras_streamable = (
                db.query(func.count(AdminCameraCatalog.camera_id))
                .filter(AdminCameraCatalog.streamable.is_(True))
                .filter(AdminCameraCatalog.hidden_by_admin.is_(False))
                .filter(AdminCameraCatalog.hidden_due_to_offline.is_(False))
                .scalar()
                or 0
            )
            cameras_hidden = (
                db.query(func.count(AdminCameraCatalog.camera_id))
                .filter(
                    (AdminCameraCatalog.hidden_by_admin.is_(True))
                    | (AdminCameraCatalog.hidden_due_to_offline.is_(True))
                )
                .scalar()
                or 0
            )
            cameras_offline = (
                db.query(func.count(AdminCameraCatalog.camera_id))
                .filter(AdminCameraCatalog.streamable.is_(False))
                .scalar()
                or 0
            )
            cameras_secret = sum(
                1
                for meta in source_index.values()
                if bool(meta.get("is_secret") is True)
            )
            cameras_public = max(0, int(cameras_total) - int(cameras_secret))
            cameras_secret_streamable = sum(
                1
                for row in db.query(AdminCameraCatalog).all()
                if row.streamable
                and not row.hidden_by_admin
                and not row.hidden_due_to_offline
                and bool(
                    (source_index.get(row.camera_id) or {}).get("is_secret") is True
                )
            )

            total_unique_users = (
                db.query(func.count(AdminRuntimeDevice.device_id)).scalar() or 0
            )
            from services.data_layer.models import Report, User
            total_registered_users = (
                db.query(func.count(User.id)).scalar() or 0
            )
            unique_report_addresses = (
                db.query(func.count(func.distinct(Report.address)))
                .filter(Report.address.is_not(None))
                .filter(Report.address != "")
                .scalar()
                or 0
            )
            unique_ips = (
                db.query(func.count(func.distinct(AdminRuntimeDevice.last_ip)))
                .filter(AdminRuntimeDevice.last_ip.is_not(None))
                .filter(AdminRuntimeDevice.last_ip != "")
                .scalar()
                or 0
            )
            requests_last_hour = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(AdminRequestEvent.happened_at >= hour_threshold)
                .scalar()
                or 0
            )
            requests_last_day = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(AdminRequestEvent.happened_at >= day_threshold)
                .scalar()
                or 0
            )
            requests_last_week = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(AdminRequestEvent.happened_at >= week_threshold)
                .scalar()
                or 0
            )
            app_launches_total = (
                db.query(func.count(AdminHeartbeatEvent.id))
                .filter(AdminHeartbeatEvent.screen == "app_boot")
                .scalar()
                or 0
            )
            top_routes_rows = (
                db.query(
                    AdminRequestEvent.route,
                    func.count(AdminRequestEvent.id).label("hits"),
                )
                .group_by(AdminRequestEvent.route)
                .order_by(desc("hits"))
                .limit(7)
                .all()
            )

            traffic_last_hour = self._sum_traffic(db, hour_threshold)
            traffic_last_day = self._sum_traffic(db, day_threshold)
            traffic_last_week = self._sum_traffic(db, week_threshold)

            camera_views_24h = (
                db.query(func.count(AdminRequestEvent.id))
                .filter(
                    AdminRequestEvent.happened_at >= day_threshold,
                    AdminRequestEvent.route.like("%/api/cameras%")
                )
                .scalar()
                or 0
            )
            new_users_today = (
                db.query(func.count(AdminRuntimeDevice.device_id))
                .filter(AdminRuntimeDevice.first_seen_at >= day_threshold)
                .scalar()
                or 0
            )
            new_users_7d = (
                db.query(func.count(AdminRuntimeDevice.device_id))
                .filter(AdminRuntimeDevice.first_seen_at >= week_threshold)
                .scalar()
                or 0
            )
            total_heartbeats_val = int(stats.total_heartbeats or 0)
            total_screen_minutes = total_heartbeats_val * 30 // 60
            avg_session_seconds = int((total_heartbeats_val * 30) / max(1, app_launches_total))

            request_events = (
                db.query(AdminRequestEvent)
                .filter(AdminRequestEvent.happened_at >= week_threshold)
                .order_by(AdminRequestEvent.happened_at.asc())
                .all()
            )
            heartbeat_events = (
                db.query(AdminHeartbeatEvent)
                .filter(AdminHeartbeatEvent.happened_at >= week_threshold)
                .order_by(AdminHeartbeatEvent.happened_at.asc())
                .all()
            )

            uptime_seconds = max(
                0,
                int((now - _as_utc(stats.started_at or now)).total_seconds()),
            )

            return {
                "storage_mode": self._storage_mode,
                "active_unique_users": len(active_devices),
                "online_users": len(active_devices),
                "total_unique_users": int(total_unique_users),
                "total_registered_users": int(total_registered_users),
                "unique_report_addresses": int(unique_report_addresses),
                "unique_ips": int(unique_ips),
                "peak_active_unique_users": int(stats.peak_active_devices or 0),
                "active_window_seconds": ACTIVE_WINDOW_SECONDS,
                "total_requests": int(stats.total_requests or 0),
                "requests_last_hour": int(requests_last_hour),
                "requests_last_24_hours": int(requests_last_day),
                "requests_last_7_days": int(requests_last_week),
                "total_heartbeats": int(stats.total_heartbeats or 0),
                "app_launches_total": int(app_launches_total),
                "camera_views_24h": int(camera_views_24h),
                "new_users_today": int(new_users_today),
                "new_users_7d": int(new_users_7d),
                "total_screen_minutes": int(total_screen_minutes),
                "avg_session_seconds": int(avg_session_seconds),
                "total_request_bytes": int(stats.total_request_bytes or 0),
                "total_response_bytes": int(stats.total_response_bytes or 0),
                "total_traffic_bytes": int(stats.total_request_bytes or 0)
                + int(stats.total_response_bytes or 0),
                "traffic_last_hour_bytes": traffic_last_hour,
                "traffic_last_24_hours_bytes": traffic_last_day,
                "traffic_last_7_days_bytes": traffic_last_week,
                "uptime_seconds": uptime_seconds,
                "uptime_human": _humanize_seconds(uptime_seconds),
                "last_activity_at": _isoformat(stats.last_activity_at),
                "active_platforms": dict(
                    Counter(device.platform or "unknown" for device in active_devices)
                ),
                "active_app_versions": dict(
                    Counter(
                        device.app_version or "unknown" for device in active_devices
                    )
                ),
                "active_screens": dict(
                    Counter(
                        device.current_screen or "unknown" for device in active_devices
                    )
                ),
                "activity_series": {
                    "hour": self._build_series(
                        request_events,
                        heartbeat_events,
                        range_seconds=LAST_HOUR_SECONDS,
                        bucket_seconds=300,
                        label_format="%H:%M",
                    ),
                    "day": self._build_series(
                        request_events,
                        heartbeat_events,
                        range_seconds=LAST_DAY_SECONDS,
                        bucket_seconds=3600,
                        label_format="%H:%M",
                    ),
                    "week": self._build_series(
                        request_events,
                        heartbeat_events,
                        range_seconds=LAST_WEEK_SECONDS,
                        bucket_seconds=LAST_DAY_SECONDS,
                        label_format="%d.%m",
                    ),
                },
                "top_routes": [
                    {"path": route, "hits": int(hits)}
                    for route, hits in top_routes_rows
                ],
                "devices": [
                    self._device_to_dict(device, policies.get(device.device_id))
                    for device in devices
                ],
                "cameras_total": int(cameras_total),
                "cameras_public": int(cameras_public),
                "cameras_secret": int(cameras_secret),
                "cameras_streamable": int(cameras_streamable),
                "cameras_secret_streamable": int(cameras_secret_streamable),
                "cameras_hidden": int(cameras_hidden),
                "cameras_offline": int(cameras_offline),
            }
        finally:
            db.close()
