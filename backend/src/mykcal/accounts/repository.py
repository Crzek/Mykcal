from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.accounts.models import UserAccount


async def get_account_by_subject(session: AsyncSession, subject: str) -> UserAccount | None:
    result = await session.execute(select(UserAccount).where(UserAccount.subject == subject))
    return result.scalar_one_or_none()
