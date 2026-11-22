"""Alta de cuentas y sincronía del nombre visible."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from mykcal import clock
from mykcal.accounts import throttle
from mykcal.accounts.models import UserAccount
from mykcal.accounts.repository import get_account_by_subject
from mykcal.config import MAX_ACTIVE_ACCOUNTS
from mykcal.core.auth import OidcClient, auth_unavailable
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.core.userinfo import fetch_display_name
from mykcal.invitations import codes
from mykcal.invitations.models import InvitationCode

# Mismo bloqueo para altas y rotaciones (research R7).
REGISTRATION_LOCK_KEY = 0x4D594B43
NAME_REFRESH_AFTER = timedelta(hours=24)
FALLBACK_NAME = "Usuario"


async def lock_registration(session: AsyncSession) -> None:
    await session.execute(text(f"SELECT pg_advisory_xact_lock({REGISTRATION_LOCK_KEY})"))


async def count_active(session: AsyncSession) -> int:
    result = await session.execute(
        select(func.count()).select_from(UserAccount).where(UserAccount.status == "active")
    )
    return int(result.scalar_one())


async def sync_display_name(
    session: AsyncSession, account: UserAccount, oidc: OidcClient, token: str
) -> None:
    now = clock.utcnow()
    if now - account.display_name_synced_at < NAME_REFRESH_AFTER:
        return
    name = await fetch_display_name(oidc, token)
    if name:
        account.display_name = name
        account.display_name_synced_at = now
        await session.commit()


async def register(
    sessionmaker: async_sessionmaker[AsyncSession],
    *,
    subject: str,
    raw_code: str,
    token: str,
    is_admin: bool,
    oidc: OidcClient,
) -> UserAccount:
    error: ApiError | None = None
    account: UserAccount | None = None
    async with sessionmaker() as session, session.begin():
        await lock_registration(session)
        now = clock.utcnow()
        if await get_account_by_subject(session, subject) is not None:
            raise ApiError(409, ErrorCode.ALREADY_REGISTERED, "Ya tienes cuenta en Mykcal.")
        if not is_admin:
            wait = await throttle.active_block(session, subject, now)
            if wait is not None:
                raise ApiError(
                    429,
                    ErrorCode.TOO_MANY_ATTEMPTS,
                    "Demasiados intentos. Espera antes de volver a probar.",
                    retry_after_s=wait,
                )
            current = (
                await session.execute(
                    select(InvitationCode).where(InvitationCode.is_current.is_(True))
                )
            ).scalar_one_or_none()
            if current is None or not codes.matches(raw_code, current.code):
                await throttle.register_failure(session, subject, now)
                error = ApiError(
                    400, ErrorCode.INVITATION_INVALID, "El código de invitación no es válido."
                )
        if error is None:
            if await count_active(session) >= MAX_ACTIVE_ACCOUNTS:
                raise ApiError(409, ErrorCode.NO_SEATS, "No hay plazas libres.")
            name = await fetch_display_name(oidc, token)
            if name is None and not is_admin:
                raise auth_unavailable()
            account = UserAccount(
                subject=subject,
                display_name=name or FALLBACK_NAME,
                display_name_synced_at=now,
                status="active",
                created_at=now,
            )
            session.add(account)
            await throttle.clear(session, subject)
    if error is not None:
        raise error
    assert account is not None
    return account
