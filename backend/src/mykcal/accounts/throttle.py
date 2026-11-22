"""Espera creciente por identidad y bloqueo global (FR-013, research R8)."""

from __future__ import annotations

import math
from datetime import datetime, timedelta

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.accounts.models import RegistrationFailure, RegistrationThrottle

FREE_ATTEMPTS = 3
BASE_WAIT_S = 30
MAX_WAIT_S = 3600
GLOBAL_THRESHOLD = 20
GLOBAL_WINDOW = timedelta(minutes=10)
PRUNE_AFTER = timedelta(hours=1)


def backoff_seconds(consecutive_failures: int) -> int:
    if consecutive_failures <= FREE_ATTEMPTS:
        return 0
    return min(BASE_WAIT_S * 2 ** (consecutive_failures - FREE_ATTEMPTS - 1), MAX_WAIT_S)


def global_block_until(failures: list[datetime], now: datetime) -> datetime | None:
    """Bloqueo hasta 10 min después del último fallo si hay ≥ 20 en los últimos 10 min."""
    recent = [f for f in failures if f > now - GLOBAL_WINDOW]
    if len(recent) < GLOBAL_THRESHOLD:
        return None
    until = max(recent) + GLOBAL_WINDOW
    return until if until > now else None


def seconds_until(until: datetime, now: datetime) -> int:
    return max(1, math.ceil((until - now).total_seconds()))


async def active_block(session: AsyncSession, subject: str, now: datetime) -> int | None:
    """Segundos de espera pendientes (global o por identidad), o None si puede intentarlo."""
    await session.execute(
        delete(RegistrationFailure).where(RegistrationFailure.failed_at < now - PRUNE_AFTER)
    )
    rows = await session.execute(
        select(RegistrationFailure.failed_at).where(
            RegistrationFailure.failed_at > now - GLOBAL_WINDOW
        )
    )
    blocked = global_block_until(list(rows.scalars()), now)
    if blocked is not None:
        return seconds_until(blocked, now)
    row = (
        await session.execute(
            select(RegistrationThrottle)
            .where(RegistrationThrottle.subject == subject)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if row is not None and row.blocked_until is not None and row.blocked_until > now:
        return seconds_until(row.blocked_until, now)
    return None


async def register_failure(session: AsyncSession, subject: str, now: datetime) -> None:
    row = (
        await session.execute(
            select(RegistrationThrottle)
            .where(RegistrationThrottle.subject == subject)
            .with_for_update()
        )
    ).scalar_one_or_none()
    n = (row.consecutive_failures if row else 0) + 1
    wait = backoff_seconds(n)
    blocked_until = now + timedelta(seconds=wait) if wait else None
    if row is None:
        session.add(
            RegistrationThrottle(
                subject=subject,
                consecutive_failures=n,
                last_failure_at=now,
                blocked_until=blocked_until,
            )
        )
    else:
        row.consecutive_failures = n
        row.last_failure_at = now
        row.blocked_until = blocked_until
    session.add(RegistrationFailure(failed_at=now))


async def clear(session: AsyncSession, subject: str) -> None:
    await session.execute(
        delete(RegistrationThrottle).where(RegistrationThrottle.subject == subject)
    )


async def count_recent_failures(session: AsyncSession, now: datetime) -> int:
    result = await session.execute(
        select(func.count())
        .select_from(RegistrationFailure)
        .where(RegistrationFailure.failed_at > now - GLOBAL_WINDOW)
    )
    return int(result.scalar_one())
