from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.auth import Principal, require_consent
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.db import get_session
from mykcal.profile.service import calc_data_now
from mykcal.targets import service
from mykcal.targets.schemas import DailyTarget, TargetValues

router = APIRouter()


@router.get("/v1/target", response_model=DailyTarget)
async def get_target(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DailyTarget:
    assert principal.account is not None
    row = await service.current_target(session, principal.account.id)
    if row is None:
        raise ApiError(404, ErrorCode.TARGET_NOT_FOUND, "Aún no tienes objetivo diario.")
    return service.to_out(row)


@router.put("/v1/target", response_model=DailyTarget)
async def put_target(
    body: TargetValues,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DailyTarget:
    assert principal.account is not None
    row = await service.save_manual(session, principal.account.id, body, clock.utcnow())
    out = service.to_out(row)
    await session.commit()
    return out


@router.post("/v1/target/recalculate", response_model=DailyTarget)
async def post_recalculate(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DailyTarget:
    assert principal.account is not None
    calc = await calc_data_now(session, principal.account.id)
    row = await service.recalculate(session, principal.account.id, calc, clock.utcnow())
    out = service.to_out(row)
    await session.commit()
    return out
