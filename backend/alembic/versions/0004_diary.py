"""Diario de comidas: diary_entry

Revision ID: 0004_diary
Revises: 0003_foods
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0004_diary"
down_revision = "0003_foods"
branch_labels = None
depends_on = None

REQUIRED = ("kcal", "protein_g", "carbs_g", "fat_g")
OPTIONAL = (
    "fiber_g",
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "magnesium_mg",
    "vitamin_d_ug",
    "vitamin_c_mg",
)


def upgrade() -> None:
    op.create_table(
        "diary_entry",
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
        sa.Column("entry_date", sa.Date, nullable=False),
        sa.Column("meal", sa.Text, nullable=False),
        sa.Column(
            "food_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("food.id"), nullable=False
        ),
        sa.Column("food_kind", sa.Text, nullable=False),
        sa.Column("food_name", sa.Text, nullable=False),
        sa.Column("food_brand", sa.Text, nullable=True),
        sa.Column("base_unit", sa.Text, nullable=False),
        sa.Column("serving_size", sa.Numeric(7, 2), nullable=True),
        *(sa.Column(name, sa.Numeric(8, 2), nullable=False) for name in REQUIRED),
        *(sa.Column(name, sa.Numeric(8, 2), nullable=True) for name in OPTIONAL),
        sa.Column("quantity", sa.Numeric(7, 1), nullable=False),
        sa.Column("servings", sa.Numeric(5, 2), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "meal IN ('breakfast','lunch','afternoon_snack','dinner','snacks')",
            name="ck_diary_meal",
        ),
        sa.CheckConstraint("base_unit IN ('g','ml')", name="ck_diary_unit"),
        sa.CheckConstraint("quantity > 0 AND quantity <= 10000", name="ck_diary_quantity"),
        sa.CheckConstraint(
            "servings IS NULL OR (servings > 0 AND servings <= 100)", name="ck_diary_servings"
        ),
        sa.CheckConstraint(
            "servings IS NULL OR serving_size IS NOT NULL", name="ck_diary_servings_size"
        ),
        sa.CheckConstraint(
            " AND ".join(f"({name} IS NULL OR {name} >= 0)" for name in (*REQUIRED, *OPTIONAL)),
            name="ck_diary_nutrients",
        ),
    )
    op.create_index(
        "ix_diary_entry_user_date",
        "diary_entry",
        ["user_id", "entry_date"],
        postgresql_where=sa.text("deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_diary_entry_user_date", table_name="diary_entry")
    op.drop_table("diary_entry")
