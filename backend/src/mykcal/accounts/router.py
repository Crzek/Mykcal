from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.accounts import service
from mykcal.accounts.models import UserAccount
from mykcal.accounts.schemas import Me, RegistrationRequest
from mykcal.core.auth import Principal, get_principal, require_active_account
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.db import get_session

router = APIRouter()


def _me(account: UserAccount, is_admin: bool, onboarding: str) -> Me:
    return Me(
        id=account.id,
        display_name=account.display_name,
        is_admin=is_admin,
        status=account.status,  # type: ignore[arg-type]
        onboarding=onboarding,  # type: ignore[arg-type]
    )


@router.get("/v1/me", response_model=Me)
async def get_me(
    request: Request,
    principal: Principal = Depends(get_principal),
    session: AsyncSession = Depends(get_session),
) -> Me:
    if principal.account is None:
        raise ApiError(404, ErrorCode.ACCOUNT_NOT_REGISTERED, "Aún no tienes cuenta en Mykcal.")
    await service.sync_display_name(
        session, principal.account, request.app.state.oidc, principal.token
    )
    onboarding = await service.onboarding_state(session, principal.account.id)
    return _me(principal.account, principal.is_admin, onboarding)


@router.post("/v1/registration", response_model=Me, status_code=201)
async def post_registration(
    body: RegistrationRequest,
    request: Request,
    principal: Principal = Depends(get_principal),
) -> Me:
    account = await service.register(
        request.app.state.sessionmaker,
        subject=principal.subject,
        raw_code=body.invitation_code,
        token=principal.token,
        is_admin=principal.is_admin,
        oidc=request.app.state.oidc,
    )
    return _me(account, principal.is_admin, "consent")  # una cuenta nueva aún no consintió


@router.post("/v1/me/deactivation", status_code=204)
async def post_deactivation(
    request: Request, principal: Principal = Depends(require_active_account)
) -> Response:
    assert principal.account is not None
    await service.deactivate(request.app.state.sessionmaker, principal.account.id)
    return Response(status_code=204)
