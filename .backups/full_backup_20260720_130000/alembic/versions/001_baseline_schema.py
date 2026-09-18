"""Baseline revision for existing Soobshio deployments.

Tables were historically created via SQLAlchemy ``create_all`` at startup.
New environments should run ``alembic upgrade head`` then set
``DB_AUTO_CREATE=false`` in production.
"""

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Schema already applied on production via metadata.create_all.
    # Future revisions should use autogenerate for incremental changes.
    pass


def downgrade() -> None:
    pass
