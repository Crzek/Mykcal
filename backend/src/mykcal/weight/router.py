"""Peso, gráfica y propuesta de recálculo. Datos de salud: todas exigen consentimiento."""

from __future__ import annotations

from datetime import date as date_type
from typing import Literal

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.auth import Principal, require_consent
from mykcal.db import get_session
from mykcal.targets import service as targets
from mykcal.targets.schemas import DailyTarget
from mykcal.weight import schemas, service

router = APIRouter()

UtcOffsetMin = Query(ge=-840, le=840)


@router.get("/v1/weight", response_model=schemas.WeightList)
async def list_weight(
    from_: date_type | None = Query(default=None, alias="from"),
    to: date_type | None = None,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> schemas.WeightList:
    assert principal.account is not None
    return await service.list_entries(session, principal.account.id, from_, to)


@router.post("/v1/weight", response_model=schemas.WeightEntry)
async def save_weight(
    body: schemas.WeightInput,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> schemas.WeightEntry:
    assert principal.account is not None
    out = await service.upsert_entry(
        session, principal.account.id, principal.account, body, clock.utcnow(), utc_offset_min
    )
    await session.commit()
    return out


@router.get("/v1/weight/chart", response_model=schemas.WeightChart)
async def weight_chart(
    period: Literal["p30", "p90", "all"],
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> schemas.WeightChart:
    assert principal.account is not None
    today = service.local_today(clock.utcnow(), utc_offset_min)
    return await service.chart(session, principal.account.id, period, today)


@router.put("/v1/weight/{date}", response_model=schemas.WeightEntry)
async def update_weight(
    date: date_type,
    body: schemas.WeightUpdate,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> schemas.WeightEntry:
    assert principal.account is not None
    out = await service.update_entry(
        session, principal.account.id, date, body, clock.utcnow(), utc_offset_min
    )
    await session.commit()
    return out


@router.delete("/v1/weight/{date}", status_code=204)
async def delete_weight(
    date: date_type,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Response:
    assert principal.account is not None
    await service.delete_entry(session, principal.account.id, date, clock.utcnow(), utc_offset_min)
    await session.commit()
    return Response(status_code=204)


@router.get(
    "/v1/recalc-proposal", response_model=schemas.RecalcProposal, response_model_exclude_none=True
)
async def get_recalc_proposal(
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> schemas.RecalcProposal:
    assert principal.account is not None
    now = clock.utcnow()
    out = await service.get_proposal(
        session, principal.account.id, service.local_today(now, utc_offset_min), now
    )
    await session.commit()
    return out


@router.post("/v1/recalc-proposal/accept", response_model=DailyTarget)
async def accept_recalc_proposal(
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DailyTarget:
    assert principal.account is not None
    now = clock.utcnow()
    row = await service.accept_proposal(
        session, principal.account.id, service.local_today(now, utc_offset_min), now
    )
    out = targets.to_out(row)
    await session.commit()
    return out


@router.post("/v1/recalc-proposal/ignore", status_code=204)
async def ignore_recalc_proposal(
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Response:
    assert principal.account is not None
    now = clock.utcnow()
    await service.ignore_proposal(
        session, principal.account.id, service.local_today(now, utc_offset_min), now
    )
    await session.commit()
    return Response(status_code=204)
