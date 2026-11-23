from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    SmallInteger,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class UserProfile(Base):
    __tablename__ = "user_profile"
    __table_args__ = (
        CheckConstraint("age BETWEEN 18 AND 100", name="ck_profile_age"),
        CheckConstraint("sex IN ('male','female')", name="ck_profile_sex"),
        CheckConstraint("height_cm BETWEEN 100 AND 250", name="ck_profile_height"),
        CheckConstraint(
            "activity_level IN ('sedentary','light','moderate','high','very_high')",
            name="ck_profile_activity",
        ),
        CheckConstraint("goal IN ('lose_fat','maintain','gain_muscle')", name="ck_profile_goal"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), primary_key=True
    )
    age: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    sex: Mapped[str] = mapped_column(Text, nullable=False)
    height_cm: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    activity_level: Mapped[str] = mapped_column(Text, nullable=False)
    goal: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class WeightEntry(Base):
    __tablename__ = "weight_entry"
    __table_args__ = (
        UniqueConstraint("user_id", "measured_on", name="uq_weight_entry_user_day"),
        CheckConstraint("weight_kg BETWEEN 30 AND 300", name="ck_weight_range"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=False
    )
    measured_on: Mapped[date] = mapped_column(Date, nullable=False)
    weight_kg: Mapped[Decimal] = mapped_column(Numeric(4, 1), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
