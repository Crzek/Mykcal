"""Acceso a `ai_key`. Todo filtra por `user_id` (principio V)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.ai.models import AiKey


async def get_key(session: AsyncSession, user_id: uuid.UUID) -> AiKey | None:
    return (
        await session.execute(select(AiKey).where(AiKey.user_id == user_id))
    ).scalar_one_or_none()


async def upsert_key(
    session: AsyncSession,
    user_id: uuid.UUID,
    provider: str,
    encrypted_key: bytes,
    now: datetime,
) -> AiKey:
    stmt = insert(AiKey).values(
        user_id=user_id, provider=provider, encrypted_key=encrypted_key, configured_at=now
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[AiKey.user_id],
        set_={"provider": provider, "encrypted_key": encrypted_key, "configured_at": now},
    )
    await session.execute(stmt)
    await session.commit()
    row = await get_key(session, user_id)
    assert row is not None
    return row


async def delete_key(session: AsyncSession, user_id: uuid.UUID) -> bool:
    result = await session.execute(delete(AiKey).where(AiKey.user_id == user_id))
    await session.commit()
    return result.rowcount > 0
