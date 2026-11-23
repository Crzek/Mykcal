"""Acceso por invitación: user_account, invitation_code, registration_throttle/failure

Revision ID: 0001_access
Revises:
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0001_access"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_account",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("subject", sa.Text, nullable=False, unique=True),
        sa.Column("display_name", sa.Text, nullable=False),
        sa.Column("display_name_synced_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.Text, nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("disabled_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("status IN ('active','disabled')", name="ck_user_account_status"),
        sa.CheckConstraint(
            "(status = 'disabled') = (disabled_at IS NOT NULL)", name="ck_user_account_disabled_at"
        ),
        sa.CheckConstraint(
            "char_length(display_name) BETWEEN 1 AND 200", name="ck_user_account_display_name"
        ),
    )
    op.create_index(
        "ix_user_account_active",
        "user_account",
        ["status"],
        postgresql_where=sa.text("status = 'active'"),
    )
    op.create_table(
        "invitation_code",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("code", sa.Text, nullable=False, unique=True),
        sa.Column("is_current", sa.Boolean, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("user_account.id"),
            nullable=False,
        ),
        sa.Column("superseded_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("code ~ '^[0-9A-HJKMNP-TV-Z]{8}$'", name="ck_invitation_code_format"),
        sa.CheckConstraint("is_current = (superseded_at IS NULL)", name="ck_invitation_superseded"),
    )
    op.create_index(
        "uq_invitation_code_current",
        "invitation_code",
        ["is_current"],
        unique=True,
        postgresql_where=sa.text("is_current"),
    )
    op.create_table(
        "registration_throttle",
        sa.Column("subject", sa.Text, primary_key=True),
        sa.Column("consecutive_failures", sa.Integer, nullable=False),
        sa.Column("last_failure_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("blocked_until", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("consecutive_failures >= 1", name="ck_throttle_failures"),
    )
    op.create_table(
        "registration_failure",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("failed_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_registration_failure_failed_at", "registration_failure", ["failed_at"])


def downgrade() -> None:
    op.drop_table("registration_failure")
    op.drop_table("registration_throttle")
    op.drop_table("invitation_code")
    op.drop_table("user_account")
