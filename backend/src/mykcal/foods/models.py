from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class Food(Base):
    """Genérico (CIQUAL), envasado (OFF) o personalizado. Restricciones en 0003_foods."""

    __tablename__ = "food"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    kind: Mapped[str] = mapped_column(Text, nullable=False)
    owner_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=True
    )
    name: Mapped[str] = mapped_column(Text, nullable=False)
    brand: Mapped[str | None] = mapped_column(Text, nullable=True)
    barcode: Mapped[str | None] = mapped_column(Text, nullable=True)
    base_unit: Mapped[str] = mapped_column(Text, nullable=False)

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

    serving_size: Mapped[Decimal | None] = mapped_column(Numeric(7, 2), nullable=True)
    synonyms: Mapped[str | None] = mapped_column(Text, nullable=True)
    search_text: Mapped[str] = mapped_column(Text, nullable=False)
    source: Mapped[str] = mapped_column(Text, nullable=False)
    source_code: Mapped[str | None] = mapped_column(Text, nullable=True)
    fetched_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class FoodImport(Base):
    __tablename__ = "food_import"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    source: Mapped[str] = mapped_column(Text, nullable=False)
    edition: Mapped[str] = mapped_column(Text, nullable=False)
    sha256: Mapped[str] = mapped_column(Text, nullable=False)
    rows_upserted: Mapped[int] = mapped_column(Integer, nullable=False)
    rows_archived: Mapped[int] = mapped_column(Integer, nullable=False)
    imported_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
