"""Add agent tables for Soobshio Agent Core.

Creates: agent_threads, agent_messages, agent_jobs, agent_facts, agent_tool_logs.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "002_agent_tables"
down_revision: Union[str, None] = "001_baseline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "agent_threads",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("source", sa.String(80), nullable=False, server_default="manual"),
        sa.Column("scope", sa.String(120), nullable=False, server_default="internal"),
        sa.Column("task_type", sa.String(40), nullable=False, server_default="analyze"),
        sa.Column("title", sa.String(200), nullable=True),
        sa.Column("status", sa.String(30), nullable=False, server_default="open"),
        sa.Column("metadata_json", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=True),
        sa.Column("updated_at", sa.DateTime, nullable=True),
    )
    op.create_index("idx_agent_thread_status", "agent_threads", ["status"])
    op.create_index("idx_agent_thread_created", "agent_threads", ["created_at"])

    op.create_table(
        "agent_messages",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "thread_id",
            sa.Integer,
            sa.ForeignKey("agent_threads.id"),
            nullable=False,
        ),
        sa.Column("role", sa.String(30), nullable=False),
        sa.Column("content", sa.Text, nullable=True),
        sa.Column("structured_payload", sa.Text, nullable=True),
        sa.Column("model", sa.String(120), nullable=True),
        sa.Column("prompt_tokens", sa.Integer, nullable=True),
        sa.Column("completion_tokens", sa.Integer, nullable=True),
        sa.Column("total_tokens", sa.Integer, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=True),
    )
    op.create_index(
        "idx_agent_message_thread", "agent_messages", ["thread_id", "created_at"]
    )

    op.create_table(
        "agent_jobs",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "thread_id",
            sa.Integer,
            sa.ForeignKey("agent_threads.id"),
            nullable=False,
        ),
        sa.Column("job_type", sa.String(40), nullable=False),
        sa.Column("priority", sa.String(20), nullable=False, server_default="normal"),
        sa.Column("status", sa.String(30), nullable=False, server_default="queued"),
        sa.Column("context_json", sa.Text, nullable=True),
        sa.Column("result_summary", sa.Text, nullable=True),
        sa.Column("error_text", sa.Text, nullable=True),
        sa.Column("started_at", sa.DateTime, nullable=True),
        sa.Column("finished_at", sa.DateTime, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=True),
    )
    op.create_index(
        "idx_agent_job_status", "agent_jobs", ["status", "created_at"]
    )
    op.create_index(
        "idx_agent_job_thread", "agent_jobs", ["thread_id", "created_at"]
    )

    op.create_table(
        "agent_facts",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "thread_id",
            sa.Integer,
            sa.ForeignKey("agent_threads.id"),
            nullable=False,
        ),
        sa.Column("fact_key", sa.String(120), nullable=False),
        sa.Column("fact_value", sa.Text, nullable=False),
        sa.Column("confidence", sa.Float, default=0.0),
        sa.Column("expires_at", sa.DateTime, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=True),
    )
    op.create_index(
        "idx_agent_fact_thread_key", "agent_facts", ["thread_id", "fact_key"]
    )

    op.create_table(
        "agent_tool_logs",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "thread_id",
            sa.Integer,
            sa.ForeignKey("agent_threads.id"),
            nullable=False,
        ),
        sa.Column(
            "job_id",
            sa.Integer,
            sa.ForeignKey("agent_jobs.id"),
            nullable=True,
        ),
        sa.Column("tool_name", sa.String(80), nullable=False),
        sa.Column("input_summary", sa.Text, nullable=True),
        sa.Column("output_summary", sa.Text, nullable=True),
        sa.Column("latency_ms", sa.Integer, nullable=True),
        sa.Column("success", sa.Boolean, default=False),
        sa.Column("created_at", sa.DateTime, nullable=True),
    )
    op.create_index(
        "idx_agent_tool_job", "agent_tool_logs", ["job_id", "created_at"]
    )
    op.create_index(
        "idx_agent_tool_thread", "agent_tool_logs", ["thread_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_table("agent_tool_logs")
    op.drop_table("agent_facts")
    op.drop_table("agent_jobs")
    op.drop_table("agent_messages")
    op.drop_table("agent_threads")
