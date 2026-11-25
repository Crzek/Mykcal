"""Registro rápido: favorite_food y diary_entry.copy_id

Revision ID: 0005_quick
Revises: 0004_diary
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0005_quick"
down_revision = "0004_diary"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "favorite_food",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("user_account.id"),
            nullable=False,
        ),
        sa.Column(
            "food_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("food.id"), nullable=False
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("user_id", "food_id", name="pk_favorite_food"),
    )
    op.add_column("diary_entry", sa.Column("copy_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_index(
        "ix_diary_entry_copy",
        "diary_entry",
        ["user_id", "copy_id"],
        postgresql_where=sa.text("copy_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_diary_entry_copy", table_name="diary_entry")
    op.drop_column("diary_entry", "copy_id")
    op.drop_table("favorite_food")
