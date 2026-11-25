from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, LargeBinary, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class AiKey(Base):
    """Clave de IA de un usuario, cifrada con AES-256-GCM (data-model.md, research R1)."""

    __tablename__ = "ai_key"
    __table_args__ = (CheckConstraint("provider IN ('gemini')", name="ck_ai_key_provider"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), primary_key=True
    )
    provider: Mapped[str] = mapped_column(Text, nullable=False)
    encrypted_key: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    configured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
