from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class InvitationCode(Base):
    __tablename__ = "invitation_code"
    __table_args__ = (
        CheckConstraint("code ~ '^[0-9A-HJKMNP-TV-Z]{8}$'", name="ck_invitation_code_format"),
        CheckConstraint("is_current = (superseded_at IS NULL)", name="ck_invitation_superseded"),
        Index(
            "uq_invitation_code_current",
            "is_current",
            unique=True,
            postgresql_where=text("is_current"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    code: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    is_current: Mapped[bool] = mapped_column(Boolean, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("user_account.id"), nullable=False
    )
    superseded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
