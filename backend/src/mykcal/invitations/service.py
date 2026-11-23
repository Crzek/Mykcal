from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.accounts.service import count_active, lock_registration
from mykcal.config import MAX_ACTIVE_ACCOUNTS
from mykcal.invitations import codes
from mykcal.invitations.models import InvitationCode


@dataclass
class InvitationStatus:
    code: str | None
    created_at: datetime | None
    active_accounts: int
    max_accounts: int
    free_seats: int


async def get_status(session: AsyncSession) -> InvitationStatus:
    current = (
        await session.execute(select(InvitationCode).where(InvitationCode.is_current.is_(True)))
    ).scalar_one_or_none()
    active = await count_active(session)
    return InvitationStatus(
        code=current.code if current else None,
        created_at=current.created_at if current else None,
        active_accounts=active,
        max_accounts=MAX_ACTIVE_ACCOUNTS,
        free_seats=max(0, MAX_ACTIVE_ACCOUNTS - active),
    )


async def rotate(session: AsyncSession, admin_id: uuid.UUID) -> InvitationStatus:
    async with session.begin_nested() if session.in_transaction() else session.begin():
        await lock_registration(session)
        now = clock.utcnow()
        await session.execute(
            update(InvitationCode)
            .where(InvitationCode.is_current.is_(True))
            .values(is_current=False, superseded_at=now)
        )
        for _ in range(5):
            try:
                async with session.begin_nested():
                    session.add(
                        InvitationCode(
                            code=codes.generate(),
                            is_current=True,
                            created_at=now,
                            created_by=admin_id,
                        )
                    )
                break
            except IntegrityError:
                continue
        else:  # pragma: no cover - 40 bits: colisión improbable
            raise RuntimeError("no se pudo generar un código único")
    await session.commit()
    return await get_status(session)
