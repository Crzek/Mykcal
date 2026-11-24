"""Base de alimentos: pg_trgm, food, food_import

Revision ID: 0003_foods
Revises: 0002_onboarding
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0003_foods"
down_revision = "0002_onboarding"
branch_labels = None
depends_on = None

# Máximos por 100 g o 100 ml (data-model.md). Los cuatro primeros son obligatorios.
NUTRIENT_MAX = {
    "kcal": 900,
    "protein_g": 100,
    "carbs_g": 100,
    "fat_g": 100,
    "fiber_g": 100,
    "sodium_mg": 40000,
    "potassium_mg": 10000,
    "calcium_mg": 5000,
    "iron_mg": 500,
    "magnesium_mg": 2000,
    "vitamin_d_ug": 1000,
    "vitamin_c_mg": 5000,
}
REQUIRED = {"kcal", "protein_g", "carbs_g", "fat_g"}


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    op.create_table(
        "food",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("kind", sa.Text, nullable=False),
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("user_account.id"),
            nullable=True,
        ),
        sa.Column("name", sa.Text, nullable=False),
        sa.Column("brand", sa.Text, nullable=True),
        sa.Column("barcode", sa.Text, nullable=True),
        sa.Column("base_unit", sa.Text, nullable=False),
        *(
            sa.Column(name, sa.Numeric(8, 2), nullable=name not in REQUIRED)
            for name in NUTRIENT_MAX
        ),
        sa.Column("serving_size", sa.Numeric(7, 2), nullable=True),
        sa.Column("synonyms", sa.Text, nullable=True),
        sa.Column("search_text", sa.Text, nullable=False),
        sa.Column("source", sa.Text, nullable=False),
        sa.Column("source_code", sa.Text, nullable=True),
        sa.Column("fetched_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("kind IN ('generic','packaged','custom')", name="ck_food_kind"),
        sa.CheckConstraint("(kind = 'custom') = (owner_user_id IS NOT NULL)", name="ck_food_owner"),
        sa.CheckConstraint(
            "(kind = 'generic' AND source = 'ciqual' AND source_code IS NOT NULL)"
            " OR (kind = 'packaged' AND source = 'off' AND barcode IS NOT NULL"
            " AND fetched_at IS NOT NULL)"
            " OR (kind = 'custom' AND source = 'user')",
            name="ck_food_source",
        ),
        sa.CheckConstraint("deleted_at IS NULL OR kind = 'custom'", name="ck_food_deleted"),
        sa.CheckConstraint("archived_at IS NULL OR kind = 'generic'", name="ck_food_archived"),
        sa.CheckConstraint(
            "barcode IS NULL OR barcode ~ '^[0-9]{8}$|^[0-9]{13,14}$'", name="ck_food_barcode"
        ),
        sa.CheckConstraint("base_unit IN ('g','ml')", name="ck_food_unit"),
        sa.CheckConstraint("char_length(name) BETWEEN 1 AND 120", name="ck_food_name"),
        sa.CheckConstraint("brand IS NULL OR char_length(brand) <= 80", name="ck_food_brand"),
        sa.CheckConstraint(
            "serving_size IS NULL OR (serving_size > 0 AND serving_size <= 5000)",
            name="ck_food_serving",
        ),
        *(
            sa.CheckConstraint(
                f"{name} IS NULL OR ({name} >= 0 AND {name} <= {limit})", name=f"ck_food_{name}"
            )
            for name, limit in NUTRIENT_MAX.items()
        ),
    )
    op.create_index(
        "uq_food_generic_code",
        "food",
        ["source", "source_code"],
        unique=True,
        postgresql_where=sa.text("kind = 'generic'"),
    )
    op.create_index(
        "uq_food_packaged_barcode",
        "food",
        ["barcode"],
        unique=True,
        postgresql_where=sa.text("kind = 'packaged'"),
    )
    op.create_index(
        "uq_food_custom_barcode",
        "food",
        ["owner_user_id", "barcode"],
        unique=True,
        postgresql_where=sa.text("kind = 'custom' AND deleted_at IS NULL AND barcode IS NOT NULL"),
    )
    op.create_index(
        "ix_food_custom_owner",
        "food",
        ["owner_user_id"],
        postgresql_where=sa.text("kind = 'custom' AND deleted_at IS NULL"),
    )
    op.execute("CREATE INDEX ix_food_search_trgm ON food USING gin (search_text gin_trgm_ops)")

    op.create_table(
        "food_import",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("source", sa.Text, nullable=False),
        sa.Column("edition", sa.Text, nullable=False),
        sa.Column("sha256", sa.Text, nullable=False),
        sa.Column("rows_upserted", sa.Integer, nullable=False),
        sa.Column("rows_archived", sa.Integer, nullable=False),
        sa.Column("imported_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("food_import")
    op.drop_table("food")
    op.execute("DROP EXTENSION IF EXISTS pg_trgm")
