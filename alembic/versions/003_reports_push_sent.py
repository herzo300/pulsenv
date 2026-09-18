"""Add push_sent column to reports.

Раньше колонка добавлялась рантайм-ALTER TABLE в app.py
(check_and_add_columns). Теперь изменение схемы идёт только через миграции.
Миграция идемпотентна: если колонка уже существует, ничего не делает.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "003_reports_push_sent"
down_revision: Union[str, None] = "002_agent_tables"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table: str, column: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c["name"] for c in inspector.get_columns(table)]
    return column in columns


def upgrade() -> None:
    if not _has_column("reports", "push_sent"):
        op.add_column(
            "reports",
            sa.Column(
                "push_sent",
                sa.Boolean,
                nullable=False,
                server_default=sa.false(),
            ),
        )


def downgrade() -> None:
    if _has_column("reports", "push_sent"):
        op.drop_column("reports", "push_sent")
