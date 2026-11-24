"""Lógica de alimentos: búsqueda, detalle y mapeo a los esquemas de la API."""

from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.core.errors import ApiError, ErrorCode
from mykcal.foods import custom_rules, repository
from mykcal.foods.gtin import normalize_gtin
from mykcal.foods.models import Food
from mykcal.foods.nutrients import NUTRIENTS
from mykcal.foods.off_client import OffClient, OffResult, OffUnavailable
from mykcal.foods.schemas import (
    BarcodeLookup,
    CustomFoodInput,
    CustomFoodList,
    CustomFoodSaved,
    FoodSearchResult,
    FoodSummary,
    Nutrients,
)
from mykcal.foods.schemas import Food as FoodOut
from mykcal.foods.text import normalize
from mykcal.logging import get_logger

MIN_QUERY_CHARS = 2
SEARCH_LIMIT = 20
_KIND_RANK = {"custom": 0, "generic": 1, "packaged": 2}
CACHE_MAX_AGE = timedelta(days=30)


def _num(value: Decimal | None) -> float | None:
    return None if value is None else float(value)


def to_nutrients(food: Food) -> Nutrients:
    return Nutrients(**{name: _num(getattr(food, name)) for name in NUTRIENTS})


def to_summary(food: Food, user_id: uuid.UUID) -> FoodSummary:
    return FoodSummary(
        id=food.id,
        kind=food.kind,  # type: ignore[arg-type]
        name=food.name,
        brand=food.brand,
        base_unit=food.base_unit,  # type: ignore[arg-type]
        kcal=float(food.kcal),
        is_mine=food.owner_user_id == user_id,
    )


def to_food(food: Food, user_id: uuid.UUID) -> FoodOut:
    return FoodOut(
        id=food.id,
        kind=food.kind,  # type: ignore[arg-type]
        name=food.name,
        brand=food.brand,
        barcode=food.barcode,
        base_unit=food.base_unit,  # type: ignore[arg-type]
        per_100=to_nutrients(food),
        serving_size=_num(food.serving_size),
        is_mine=food.owner_user_id == user_id,
        source=food.source,  # type: ignore[arg-type]
        updated_at=food.updated_at,
    )


def _match_rank(food: Food, q_norm: str) -> int:
    """0 nombre exacto, 1 empieza por la consulta, 2 una palabra empieza por ella, 3 el resto."""
    name = normalize(food.name)
    if name == q_norm:
        return 0
    if name.startswith(q_norm):
        return 1
    if f" {q_norm}" in f" {food.search_text}":
        return 2
    return 3


def rank_candidates(
    candidates: list[repository.Candidate], q_norm: str
) -> list[repository.Candidate]:
    """Personalizados → genéricos → envasados; dentro de cada tipo, por coincidencia (R6)."""
    return sorted(
        candidates,
        key=lambda c: (
            _KIND_RANK[c.food.kind],
            _match_rank(c.food, q_norm),
            -c.similarity,
            len(c.food.name),
            c.food.name,
        ),
    )


async def search_foods(session: AsyncSession, user_id: uuid.UUID, query: str) -> FoodSearchResult:
    q_norm = normalize(query)
    if len(q_norm) < MIN_QUERY_CHARS:
        raise ApiError(
            400, ErrorCode.VALIDATION_ERROR, "Escribe al menos 2 caracteres.", fields=["q"]
        )
    ranked = rank_candidates(await repository.search(session, user_id, q_norm), q_norm)
    return FoodSearchResult(items=[to_summary(c.food, user_id) for c in ranked[:SEARCH_LIMIT]])


async def get_food(session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID) -> FoodOut:
    food = await repository.get_visible(session, user_id, food_id)
    if food is None:
        raise food_not_found()
    return to_food(food, user_id)


def food_not_found() -> ApiError:
    """Mismo cuerpo para un id inexistente, eliminado o de otro usuario (research R14)."""
    return ApiError(404, ErrorCode.FOOD_NOT_FOUND, "Alimento no encontrado.")


@dataclass
class _Outcome:
    result: str
    lookup: BarcodeLookup


def _log_lookup(user_id: uuid.UUID, result: str, started: float) -> None:
    # Nunca el código: dice qué compra una persona (research R15).
    get_logger().info(
        "barcode_lookup",
        user_id=str(user_id),
        result=result,
        duration_ms=int((time.monotonic() - started) * 1000),
    )


def _found(
    food: Food, user_id: uuid.UUID, code: str, *, stale: bool | None = None
) -> BarcodeLookup:
    extra = {} if stale is None else {"stale": stale}
    return BarcodeLookup(result="found", code=code, food=to_food(food, user_id), **extra)


async def _from_off(
    session: AsyncSession,
    user_id: uuid.UUID,
    code: str,
    off: OffClient,
    now: datetime,
    copy: Food | None,
) -> _Outcome:
    """Consulta OFF. Una copia caducada se sirve con `stale` si OFF falla o ya no lo tiene."""
    try:
        result: OffResult = await off.fetch(code)
    except OffUnavailable:
        if copy is not None:
            return _Outcome("stale", _found(copy, user_id, code, stale=True))
        raise ApiError(
            503,
            ErrorCode.FOOD_SOURCE_UNAVAILABLE,
            "No hemos podido consultar la base de productos.",
        ) from None
    if result.status == "found" and result.product is not None:
        saved = await repository.upsert_packaged(session, result.product, now)
        await session.commit()
        return _Outcome("off_found", _found(saved, user_id, code))
    if copy is not None:
        return _Outcome("stale", _found(copy, user_id, code, stale=True))
    if result.status == "incomplete":
        return _Outcome(
            "off_incomplete",
            BarcodeLookup(
                result="incomplete", code=code, product_name=result.name, brand=result.brand
            ),
        )
    return _Outcome("off_not_found", BarcodeLookup(result="not_found", code=code))


async def lookup_barcode(
    session: AsyncSession, user_id: uuid.UUID, code: str, off: OffClient, now: datetime
) -> BarcodeLookup:
    """Personalizado propio → copia de 30 días o menos → Open Food Facts (research R9)."""
    started = time.monotonic()
    try:
        normalized = normalize_gtin(code)
    except ValueError:
        raise ApiError(
            400, ErrorCode.VALIDATION_ERROR, "Código de barras no válido.", fields=["code"]
        ) from None

    custom = await repository.get_custom_by_barcode(session, user_id, normalized)
    if custom is not None:
        _log_lookup(user_id, "custom", started)
        return _found(custom, user_id, normalized)

    copy = await repository.get_packaged_by_barcode(session, normalized)
    if copy is not None and copy.fetched_at is not None and now - copy.fetched_at <= CACHE_MAX_AGE:
        _log_lookup(user_id, "cache", started)
        return _found(copy, user_id, normalized)

    try:
        outcome = await _from_off(session, user_id, normalized, off, now, copy)
    except ApiError:
        _log_lookup(user_id, "off_error", started)
        raise
    _log_lookup(user_id, outcome.result, started)
    return outcome.lookup


def _custom_values(data: CustomFoodInput) -> tuple[dict, bool]:
    """Campos de la fila a partir de la entrada validada, y si hay aviso de kcal (R10)."""
    fields = custom_rules.validate(data)
    if fields:
        raise ApiError(400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=fields)
    per_100 = custom_rules.to_per_100(data)
    name = data.name.strip()
    brand = (data.brand or "").strip() or None
    barcode = normalize_gtin(data.barcode) if data.barcode else None
    values = {
        "name": name,
        "brand": brand,
        "barcode": barcode,
        "base_unit": data.base_unit,
        "serving_size": data.serving_size,
        "search_text": normalize(" ".join(p for p in (name, brand) if p)),
        **per_100,
    }
    return values, custom_rules.kcal_mismatch(per_100)


def _saved(food: Food, user_id: uuid.UUID, mismatch: bool) -> CustomFoodSaved:
    return CustomFoodSaved(
        food=to_food(food, user_id), warnings=["KCAL_MISMATCH"] if mismatch else []
    )


def _barcode_taken() -> ApiError:
    return ApiError(409, ErrorCode.FOOD_BARCODE_TAKEN, "Ya tienes un alimento con este código.")


async def create_custom(
    session: AsyncSession, user_id: uuid.UUID, data: CustomFoodInput, now: datetime
) -> CustomFoodSaved:
    values, mismatch = _custom_values(data)
    try:
        food = await repository.create_custom(session, user_id, values, now)
    except repository.BarcodeTaken:
        raise _barcode_taken() from None
    await session.commit()
    return _saved(food, user_id, mismatch)


async def update_custom(
    session: AsyncSession,
    user_id: uuid.UUID,
    food_id: uuid.UUID,
    data: CustomFoodInput,
    now: datetime,
) -> CustomFoodSaved:
    values, mismatch = _custom_values(data)
    try:
        food = await repository.update_custom(session, user_id, food_id, values, now)
    except repository.BarcodeTaken:
        raise _barcode_taken() from None
    if food is None:
        raise food_not_found()
    await session.commit()
    return _saved(food, user_id, mismatch)


async def delete_custom(
    session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID, now: datetime
) -> None:
    if not await repository.soft_delete_custom(session, user_id, food_id, now):
        raise food_not_found()
    await session.commit()


async def list_custom(session: AsyncSession, user_id: uuid.UUID) -> CustomFoodList:
    rows = await repository.list_custom(session, user_id)
    return CustomFoodList(items=[to_summary(f, user_id) for f in rows])
