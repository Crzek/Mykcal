"""Consultas del diario. Todo recibe `user_id` (principio V)."""

from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.diary.models import DiaryEntry


async def entries_of_day(session: AsyncSession, user_id: uuid.UUID, day: date) -> list[DiaryEntry]:
    """Entradas activas de un día, en orden de creación."""
    stmt = (
        select(DiaryEntry)
        .where(
            DiaryEntry.user_id == user_id,
            DiaryEntry.entry_date == day,
            DiaryEntry.deleted_at.is_(None),
        )
        .order_by(DiaryEntry.created_at, DiaryEntry.id)
    )
    return list((await session.execute(stmt)).scalars().all())


def add_entry(session: AsyncSession, entry: DiaryEntry) -> DiaryEntry:
    session.add(entry)
    return entry


async def get_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    entry_id: uuid.UUID,
    *,
    deleted: bool = False,
) -> DiaryEntry | None:
    """Entrada del usuario, activa o (con `deleted=True`) borrada. Ajena o inexistente: `None`."""
    stmt = select(DiaryEntry).where(DiaryEntry.id == entry_id, DiaryEntry.user_id == user_id)
    stmt = stmt.where(
        DiaryEntry.deleted_at.is_not(None) if deleted else DiaryEntry.deleted_at.is_(None)
    )
    return (await session.execute(stmt)).scalar_one_or_none()
