from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Index, Numeric, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class DiaryEntry(Base):
    """Un alimento con su cantidad dentro de una comida de un día (data-model.md).

    Copia el nombre y los valores por 100 del alimento al registrarla (FR-004, research R5).
    Restricciones en 0004_diary.
    """

    __tablename__ = "diary_entry"
    __table_args__ = (
        Index(
            "ix_diary_entry_user_date",
            "user_id",
            "entry_date",
            postgresql_where=text("deleted_at IS NULL"),
        ),
        Index(
            "ix_diary_entry_copy",
            "user_id",
            "copy_id",
            postgresql_where=text("copy_id IS NOT NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=False
    )
    entry_date: Mapped[date] = mapped_column(Date, nullable=False)
    meal: Mapped[str] = mapped_column(Text, nullable=False)
    food_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("food.id"), nullable=False
    )
    food_kind: Mapped[str] = mapped_column(Text, nullable=False)
    food_name: Mapped[str] = mapped_column(Text, nullable=False)
    food_brand: Mapped[str | None] = mapped_column(Text, nullable=True)
    base_unit: Mapped[str] = mapped_column(Text, nullable=False)
    serving_size: Mapped[Decimal | None] = mapped_column(Numeric(7, 2), nullable=True)

    # Copia por 100 g/ml del alimento; None = sin dato.
    kcal: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    protein_g: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    carbs_g: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    fat_g: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    fiber_g: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    sodium_mg: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    potassium_mg: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    calcium_mg: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    iron_mg: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    magnesium_mg: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    vitamin_d_ug: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    vitamin_c_mg: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)

    quantity: Mapped[Decimal] = mapped_column(Numeric(7, 1), nullable=False)
    servings: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    # Igual en todas las entradas de una misma copia de comida (005); NULL en las demás.
    copy_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
