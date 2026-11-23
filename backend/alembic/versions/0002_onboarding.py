"""Onboarding: health_consent, user_profile, weight_entry, daily_target

Revision ID: 0002_onboarding
Revises: 0001_access
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0002_onboarding"
down_revision = "0001_access"
branch_labels = None
depends_on = None

TARGET_RANGES = {
    "kcal": (1, 10000),
    "protein_g": (0, 1000),
    "carbs_g": (0, 2000),
    "fat_g": (0, 1000),
    "fiber_g": (0, 200),
    "sodium_mg": (0, 20000),
    "potassium_mg": (0, 20000),
    "calcium_mg": (0, 10000),
    "iron_mg": (0, 200),
    "magnesium_mg": (0, 5000),
    "vitamin_d_ug": (0, 500),
    "vitamin_c_mg": (0, 5000),
}


def _uuid_pk() -> sa.Column:
    return sa.Column(
        "id",
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
    )


def _user_fk(primary_key: bool = False) -> sa.Column:
    return sa.Column(
        "user_id",
        postgresql.UUID(as_uuid=True),
        sa.ForeignKey("user_account.id"),
        primary_key=primary_key,
        nullable=False,
    )


def upgrade() -> None:
    op.create_table(
        "health_consent",
        _uuid_pk(),
        _user_fk(),
        sa.Column("text_version", sa.Text, nullable=False),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "text_version", name="uq_health_consent_user_version"),
        sa.CheckConstraint("char_length(text_version) BETWEEN 1 AND 32", name="ck_consent_version"),
    )
    op.create_table(
        "user_profile",
        _user_fk(primary_key=True),
        sa.Column("age", sa.SmallInteger, nullable=False),
        sa.Column("sex", sa.Text, nullable=False),
        sa.Column("height_cm", sa.SmallInteger, nullable=False),
        sa.Column("activity_level", sa.Text, nullable=False),
        sa.Column("goal", sa.Text, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("age BETWEEN 18 AND 100", name="ck_profile_age"),
        sa.CheckConstraint("sex IN ('male','female')", name="ck_profile_sex"),
        sa.CheckConstraint("height_cm BETWEEN 100 AND 250", name="ck_profile_height"),
        sa.CheckConstraint(
            "activity_level IN ('sedentary','light','moderate','high','very_high')",
            name="ck_profile_activity",
        ),
        sa.CheckConstraint("goal IN ('lose_fat','maintain','gain_muscle')", name="ck_profile_goal"),
    )
    op.create_table(
        "weight_entry",
        _uuid_pk(),
        _user_fk(),
        sa.Column("measured_on", sa.Date, nullable=False),
        sa.Column("weight_kg", sa.Numeric(4, 1), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "measured_on", name="uq_weight_entry_user_day"),
        sa.CheckConstraint("weight_kg BETWEEN 30 AND 300", name="ck_weight_range"),
    )
    columns = [
        _uuid_pk(),
        _user_fk(),
        sa.Column("is_current", sa.Boolean, nullable=False),
        sa.Column("effective_from", sa.DateTime(timezone=True), nullable=False),
        sa.Column("superseded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source", sa.Text, nullable=False),
        *(sa.Column(name, sa.Integer, nullable=False) for name in TARGET_RANGES),
        sa.Column("calc_weight_kg", sa.Numeric(4, 1), nullable=False),
        sa.Column("calc_age", sa.SmallInteger, nullable=False),
        sa.Column("calc_sex", sa.Text, nullable=False),
        sa.Column("calc_height_cm", sa.SmallInteger, nullable=False),
        sa.Column("calc_activity", sa.Text, nullable=False),
        sa.Column("calc_goal", sa.Text, nullable=False),
        sa.Column("calculated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "calc_notices",
            postgresql.ARRAY(sa.Text),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
        sa.CheckConstraint("is_current = (superseded_at IS NULL)", name="ck_target_superseded"),
        sa.CheckConstraint("source IN ('calculated','manual')", name="ck_target_source"),
        *(
            sa.CheckConstraint(f"{col} BETWEEN {lo} AND {hi}", name=f"ck_target_{col}")
            for col, (lo, hi) in TARGET_RANGES.items()
        ),
    ]
    op.create_table("daily_target", *columns)
    op.create_index(
        "uq_daily_target_current",
        "daily_target",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("is_current"),
    )
    op.create_index("ix_daily_target_user_effective", "daily_target", ["user_id", "effective_from"])


def downgrade() -> None:
    op.drop_table("daily_target")
    op.drop_table("weight_entry")
    op.drop_table("user_profile")
    op.drop_table("health_consent")
