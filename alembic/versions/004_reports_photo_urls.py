"""Add photo_urls JSON column to reports.

Фото жалоб переносятся из текста description (конвейер
«вклеить URL → выпарсить регэкспом») в отдельную колонку photo_urls.
Миграция идемпотентна и переносит существующие URL из description.

Revision ID: 004_reports_photo_urls
Revises: 003_reports_push_sent
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "004_reports_photo_urls"
down_revision: Union[str, None] = "003_reports_push_sent"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c["name"] for c in inspector.get_columns(table)]
    return column in columns


def upgrade() -> None:
    if not _has_column("reports", "photo_urls"):
        op.add_column(
            "reports",
            sa.Column("photo_urls", sa.JSON(), nullable=True),
        )

    # Перенос существующих URL фото из description в новую колонку
    bind = op.get_bind()
    reports = bind.execute(
        sa.text(
            "SELECT id, description FROM reports "
            "WHERE photo_urls IS NULL AND description IS NOT NULL"
        )
    ).fetchall()
    if not reports:
        return

    import json
    import re

    pattern = re.compile(
        r"(https?://[^\s\]\n]+|/(?:static|media|uploads)/[^\s\]\n]+)"
    )

    def _is_image_url(url: str) -> bool:
        lower = url.lower()
        path = lower.split("?")[0]
        return (
            any(path.endswith(ext) for ext in (".jpg", ".jpeg", ".png", ".gif", ".webp"))
            or "uploads/complaints" in lower
            or "reports-media" in lower
            or "static/uploads" in lower
            or "pollinations.ai" in lower
        )

    updated = 0
    for report_id, description in reports:
        urls = [m.group(0).rstrip(".,);") for m in pattern.finditer(description or "")]
        urls = [u for u in urls if _is_image_url(u)]
        if urls:
            bind.execute(
                sa.text("UPDATE reports SET photo_urls = :urls WHERE id = :id"),
                {"urls": json.dumps(urls[:5]), "id": report_id},
            )
            updated += 1
    print(f"photo_urls backfill: migrated {updated} of {len(reports)} reports")


def downgrade() -> None:
    if _has_column("reports", "photo_urls"):
        op.drop_column("reports", "photo_urls")
