"""Create runtime indexes used by map, ingestion, and admin dashboards."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from services.data_layer.database import engine


INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_reports_source_created ON reports(source, created_at)",
    "CREATE INDEX IF NOT EXISTS idx_reports_category_created ON reports(category, created_at)",
    "CREATE INDEX IF NOT EXISTS idx_reports_address ON reports(address)",
    "CREATE INDEX IF NOT EXISTS idx_reports_geo_created ON reports(lat, lng, created_at)",
    "CREATE INDEX IF NOT EXISTS idx_reports_telegram_msg ON reports(telegram_channel, telegram_message_id)",
    "CREATE INDEX IF NOT EXISTS idx_admin_heartbeat_screen_time ON admin_heartbeat_events(screen, happened_at)",
    "CREATE INDEX IF NOT EXISTS idx_admin_heartbeat_device_time ON admin_heartbeat_events(device_id, happened_at)",
    "CREATE INDEX IF NOT EXISTS idx_admin_request_route_time ON admin_request_events(route, happened_at)",
]


def main() -> int:
    with engine.begin() as conn:
        for statement in INDEXES:
            conn.exec_driver_sql(statement)
    print({"created_or_verified": len(INDEXES)})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
