"""Peso y recálculo del objetivo: recalc_proposal

Revision ID: 0007_weight_recalc
Revises: 0006_ai_key

`ix_weight_entry_user_date (user_id, measured_on)` no se crea: la restricción única
`uq_weight_entry_user_day` de 0002 ya genera un índice equivalente.
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0007_weight_recalc"
down_revision = "0006_ai_key"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "recalc_proposal",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("user_account.id"),
            nullable=False,
        ),
        sa.Column("status", sa.Text, nullable=False),
        sa.Column("reference_weight_kg", sa.Numeric(4, 1), nullable=False),
        sa.Column("weekly_average_kg", sa.Numeric(4, 1), nullable=False),
        sa.Column(
            "target_from_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("daily_target.id"),
            nullable=False,
        ),
        sa.Column("was_manual", sa.Boolean, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ignored_until", sa.Date, nullable=True),
        sa.CheckConstraint("status IN ('pending','accepted','ignored')", name="ck_recalc_status"),
        sa.CheckConstraint(
            "(responded_at IS NULL) = (status = 'pending')", name="ck_recalc_responded"
        ),
        sa.CheckConstraint(
            "ignored_until IS NULL OR status = 'ignored'", name="ck_recalc_ignored_until"
        ),
    )
    op.create_index(
        "uq_recalc_pending",
        "recalc_proposal",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )
    op.create_index("ix_recalc_user_created", "recalc_proposal", ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_recalc_user_created", table_name="recalc_proposal")
    op.drop_index("uq_recalc_pending", table_name="recalc_proposal")
    op.drop_table("recalc_proposal")
