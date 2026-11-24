"""Rutas /v1/diary/**. Todas exigen cuenta activa y consentimiento (research R11).

Todas reciben `utc_offset_min`: el desfase de la zona del móvil al final del día (research R3).
"""

from __future__ import annotations

import uuid
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.auth import Principal, require_consent
from mykcal.db import get_session
from mykcal.diary import service
from mykcal.diary.schemas import DiaryDay, DiaryEntryCreate, DiaryEntryUpdate

router = APIRouter()

UtcOffsetMin = Query(ge=-840, le=840)


@router.get("/v1/diary/days/{date}", response_model=DiaryDay)
async def get_day(
    date: date_type,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DiaryDay:
    assert principal.account is not None
    return await service.view_day(
        session,
        principal.account.id,
        principal.account.created_at,
        date,
        utc_offset_min,
        clock.utcnow(),
    )


@router.post("/v1/diary/entries", response_model=DiaryDay, status_code=201)
async def create_entry(
    body: DiaryEntryCreate,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DiaryDay:
    assert principal.account is not None
    return await service.create_entry(
        session,
        principal.account.id,
        principal.account.created_at,
        body,
        utc_offset_min,
        clock.utcnow(),
    )


@router.patch("/v1/diary/entries/{entry_id}", response_model=DiaryDay)
async def update_entry(
    entry_id: uuid.UUID,
    body: DiaryEntryUpdate,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DiaryDay:
    assert principal.account is not None
    return await service.update_entry(
        session, principal.account.id, entry_id, body, utc_offset_min, clock.utcnow()
    )


@router.delete("/v1/diary/entries/{entry_id}", response_model=DiaryDay)
async def delete_entry(
    entry_id: uuid.UUID,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DiaryDay:
    assert principal.account is not None
    return await service.delete_entry(
        session, principal.account.id, entry_id, utc_offset_min, clock.utcnow()
    )


@router.post("/v1/diary/entries/{entry_id}/restore", response_model=DiaryDay)
async def restore_entry(
    entry_id: uuid.UUID,
    utc_offset_min: int = UtcOffsetMin,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> DiaryDay:
    assert principal.account is not None
    return await service.restore_entry(
        session, principal.account.id, entry_id, utc_offset_min, clock.utcnow()
    )
