"""Rutas de recientes y favoritos. Todas exigen cuenta activa y consentimiento (research R10).

Se registra ANTES que el router de `foods`: si no, `GET /v1/foods/{food_id}` captura `recent` y
`favorites`.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.auth import Principal, require_consent
from mykcal.db import get_session
from mykcal.quick import service
from mykcal.quick.schemas import QuickFoodList

router = APIRouter()


@router.get("/v1/foods/recent", response_model=QuickFoodList)
async def recent_foods(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> QuickFoodList:
    assert principal.account is not None
    return await service.list_recent(session, principal.account.id)


@router.get("/v1/foods/favorites", response_model=QuickFoodList)
async def favorite_foods(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> QuickFoodList:
    assert principal.account is not None
    return await service.list_favorites(session, principal.account.id)


@router.put("/v1/foods/favorites/{food_id}", status_code=204)
async def add_favorite(
    food_id: uuid.UUID,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Response:
    assert principal.account is not None
    await service.mark_favorite(session, principal.account.id, food_id, clock.utcnow())
    return Response(status_code=204)


@router.delete("/v1/foods/favorites/{food_id}", status_code=204)
async def remove_favorite(
    food_id: uuid.UUID,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Response:
    assert principal.account is not None
    await service.unmark_favorite(session, principal.account.id, food_id)
    return Response(status_code=204)
