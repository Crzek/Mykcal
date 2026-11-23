from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, DateTime, Index, Integer, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from mykcal.db import Base


class UserAccount(Base):
    __tablename__ = "user_account"
    __table_args__ = (
        CheckConstraint("status IN ('active','disabled')", name="ck_user_account_status"),
        CheckConstraint(
            "(status = 'disabled') = (disabled_at IS NOT NULL)", name="ck_user_account_disabled_at"
        ),
        CheckConstraint(
            "char_length(display_name) BETWEEN 1 AND 200", name="ck_user_account_display_name"
        ),
        Index("ix_user_account_active", "status", postgresql_where=text("status = 'active'")),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    subject: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    display_name_synced_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    status: Mapped[str] = mapped_column(Text, nullable=False, server_default="active")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    disabled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class RegistrationThrottle(Base):
    __tablename__ = "registration_throttle"
    __table_args__ = (CheckConstraint("consecutive_failures >= 1", name="ck_throttle_failures"),)

    subject: Mapped[str] = mapped_column(Text, primary_key=True)
    consecutive_failures: Mapped[int] = mapped_column(Integer, nullable=False)
    last_failure_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    blocked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class RegistrationFailure(Base):
    __tablename__ = "registration_failure"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    failed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
