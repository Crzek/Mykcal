"""Clave de IA por usuario: ai_key

Revision ID: 0006_ai_key
Revises: 0005_quick
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0006_ai_key"
down_revision = "0005_quick"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ai_key",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("user_account.id"),
            nullable=False,
        ),
        sa.Column("provider", sa.Text(), nullable=False),
        sa.Column("encrypted_key", postgresql.BYTEA(), nullable=False),
        sa.Column("configured_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("user_id", name="pk_ai_key"),
        sa.CheckConstraint("provider IN ('gemini')", name="ck_ai_key_provider"),
    )


def downgrade() -> None:
    op.drop_table("ai_key")
