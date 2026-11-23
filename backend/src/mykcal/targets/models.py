from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base

# Rangos de saneamiento del objetivo (data-model.md, research R13): (columna, mínimo, máximo).
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


class DailyTarget(Base):
    """Versión del objetivo diario. Solo una vigente por usuario (research R4)."""

    __tablename__ = "daily_target"
    __table_args__ = (
        CheckConstraint("is_current = (superseded_at IS NULL)", name="ck_target_superseded"),
        CheckConstraint("source IN ('calculated','manual')", name="ck_target_source"),
        *(
            CheckConstraint(f"{col} BETWEEN {lo} AND {hi}", name=f"ck_target_{col}")
            for col, (lo, hi) in TARGET_RANGES.items()
        ),
        Index(
            "uq_daily_target_current",
            "user_id",
            unique=True,
            postgresql_where=text("is_current"),
        ),
        Index("ix_daily_target_user_effective", "user_id", "effective_from"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=False
    )
    is_current: Mapped[bool] = mapped_column(Boolean, nullable=False)
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    superseded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    source: Mapped[str] = mapped_column(Text, nullable=False)
    kcal: Mapped[int] = mapped_column(Integer, nullable=False)
    protein_g: Mapped[int] = mapped_column(Integer, nullable=False)
    carbs_g: Mapped[int] = mapped_column(Integer, nullable=False)
    fat_g: Mapped[int] = mapped_column(Integer, nullable=False)
    fiber_g: Mapped[int] = mapped_column(Integer, nullable=False)
    sodium_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    potassium_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    calcium_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    iron_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    magnesium_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    vitamin_d_ug: Mapped[int] = mapped_column(Integer, nullable=False)
    vitamin_c_mg: Mapped[int] = mapped_column(Integer, nullable=False)
    calc_weight_kg: Mapped[Decimal] = mapped_column(Numeric(4, 1), nullable=False)
    calc_age: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    calc_sex: Mapped[str] = mapped_column(Text, nullable=False)
    calc_height_cm: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    calc_activity: Mapped[str] = mapped_column(Text, nullable=False)
    calc_goal: Mapped[str] = mapped_column(Text, nullable=False)
    calculated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    calc_notices: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, server_default=text("'{}'")
    )
