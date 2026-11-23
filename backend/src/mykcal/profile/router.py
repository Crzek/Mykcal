from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.auth import Principal, require_consent
from mykcal.db import get_session
from mykcal.profile import service
from mykcal.profile.schemas import Profile, ProfileInput, ProfileSaved

router = APIRouter()


@router.get("/v1/profile", response_model=Profile)
async def get_profile(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Profile:
    assert principal.account is not None
    return await service.get_profile(session, principal.account.id)


@router.put("/v1/profile", response_model=ProfileSaved, response_model_exclude_none=True)
async def put_profile(
    body: ProfileInput,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> ProfileSaved:
    assert principal.account is not None
    # La dependencia `require_consent` ya abrió la transacción de esta sesión: se confirma aquí.
    saved = await service.save_profile(session, principal.account.id, body, clock.utcnow())
    await session.commit()
    return saved
