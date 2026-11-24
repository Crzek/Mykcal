"""Rutas /v1/foods/**. Todas exigen cuenta activa y consentimiento (research R14).

Orden: `/search`, `/barcode` y `/custom` van siempre antes que `/{food_id}`.
"""

from __future__ import annotations

import time
import uuid

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.auth import Principal, require_consent
from mykcal.db import get_session
from mykcal.foods import service
from mykcal.foods.off_client import OffClient
from mykcal.foods.schemas import (
    BarcodeLookup,
    CustomFoodInput,
    CustomFoodList,
    CustomFoodSaved,
    Food,
    FoodSearchResult,
)
from mykcal.logging import get_logger

router = APIRouter()


@router.get("/v1/foods/search", response_model=FoodSearchResult)
async def search_foods(
    q: str = Query(max_length=100),
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> FoodSearchResult:
    assert principal.account is not None
    start = time.monotonic()
    result = await service.search_foods(session, principal.account.id, q)
    # Nunca la consulta: dice qué busca una persona (research R15).
    get_logger().info(
        "food_search",
        user_id=str(principal.account.id),
        result_count=len(result.items),
        duration_ms=int((time.monotonic() - start) * 1000),
    )
    return result


@router.get("/v1/foods/barcode", response_model=BarcodeLookup, response_model_exclude_unset=True)
async def lookup_barcode(
    request: Request,
    code: str = Query(max_length=20),
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> BarcodeLookup:
    assert principal.account is not None
    settings = request.app.state.settings
    off = OffClient(
        settings.off_base_url,
        settings.off_user_agent,
        settings.off_timeout_s,
        request.app.state.off_transport,
    )
    try:
        return await service.lookup_barcode(
            session, principal.account.id, code, off, clock.utcnow()
        )
    finally:
        await off.aclose()


@router.get("/v1/foods/custom", response_model=CustomFoodList)
async def list_custom(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> CustomFoodList:
    assert principal.account is not None
    return await service.list_custom(session, principal.account.id)


@router.post("/v1/foods/custom", response_model=CustomFoodSaved, status_code=201)
async def create_custom(
    body: CustomFoodInput,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> CustomFoodSaved:
    assert principal.account is not None
    saved = await service.create_custom(session, principal.account.id, body, clock.utcnow())
    get_logger().info(
        "custom_food_saved", user_id=str(principal.account.id), food_id=str(saved.food.id)
    )
    return saved


@router.put("/v1/foods/custom/{food_id}", response_model=CustomFoodSaved)
async def update_custom(
    food_id: uuid.UUID,
    body: CustomFoodInput,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> CustomFoodSaved:
    assert principal.account is not None
    saved = await service.update_custom(
        session, principal.account.id, food_id, body, clock.utcnow()
    )
    get_logger().info("custom_food_saved", user_id=str(principal.account.id), food_id=str(food_id))
    return saved


@router.delete("/v1/foods/custom/{food_id}", status_code=204)
async def delete_custom(
    food_id: uuid.UUID,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Response:
    assert principal.account is not None
    await service.delete_custom(session, principal.account.id, food_id, clock.utcnow())
    get_logger().info(
        "custom_food_deleted", user_id=str(principal.account.id), food_id=str(food_id)
    )
    return Response(status_code=204)


@router.get("/v1/foods/{food_id}", response_model=Food)
async def get_food(
    food_id: uuid.UUID,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Food:
    assert principal.account is not None
    return await service.get_food(session, principal.account.id, food_id)
