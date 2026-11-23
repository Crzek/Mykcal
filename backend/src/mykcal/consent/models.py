from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Text, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class HealthConsent(Base):
    """Consentimiento de datos de salud (FR-001–FR-003, research R8)."""

    __tablename__ = "health_consent"
    __table_args__ = (
        UniqueConstraint("user_id", "text_version", name="uq_health_consent_user_version"),
        CheckConstraint("char_length(text_version) BETWEEN 1 AND 32", name="ck_consent_version"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=False
    )
    text_version: Mapped[str] = mapped_column(Text, nullable=False)
    accepted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
