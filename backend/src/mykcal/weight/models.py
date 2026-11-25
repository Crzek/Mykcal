"""Propuesta de recálculo del objetivo (data-model.md). `WeightEntry` vive en `profile.models`."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class RecalcProposal(Base):
    __tablename__ = "recalc_proposal"
    __table_args__ = (
        CheckConstraint("status IN ('pending','accepted','ignored')", name="ck_recalc_status"),
        CheckConstraint(
            "(responded_at IS NULL) = (status = 'pending')", name="ck_recalc_responded"
        ),
        CheckConstraint(
            "ignored_until IS NULL OR status = 'ignored'", name="ck_recalc_ignored_until"
        ),
        Index(
            "uq_recalc_pending",
            "user_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
        ),
        Index("ix_recalc_user_created", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(Text, nullable=False)
    reference_weight_kg: Mapped[Decimal] = mapped_column(Numeric(4, 1), nullable=False)
    weekly_average_kg: Mapped[Decimal] = mapped_column(Numeric(4, 1), nullable=False)
    target_from_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("daily_target.id"), nullable=False
    )
    was_manual: Mapped[bool] = mapped_column(Boolean, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ignored_until: Mapped[date | None] = mapped_column(Date, nullable=True)
