"""Recientes y favoritos: lista de alimentos listos para añadir con un toque."""

from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.diary.models import DiaryEntry
from mykcal.foods import repository as foods_repository
from mykcal.foods.models import Food
from mykcal.foods.service import food_not_found, to_food
from mykcal.logging import get_logger
from mykcal.quick import repository
from mykcal.quick.ordering import order_favorites
from mykcal.quick.schemas import QuickFood, QuickFoodList
from mykcal.quick.suggest import LastUse, suggest_amount

RECENT_LIMIT = 30


def _quick_food(
    food: Food, last: DiaryEntry | None, user_id: uuid.UUID, favorites: set[uuid.UUID]
) -> QuickFood:
    use = None if last is None else LastUse(last.quantity, last.servings, last.serving_size)
    quantity, servings = suggest_amount(use, food.serving_size)
    return QuickFood(
        food=to_food(food, user_id),
        suggested_quantity=float(quantity),
        suggested_servings=None if servings is None else float(servings),
        last_used_at=None if last is None else last.created_at,
        is_favorite=food.id in favorites,
    )


async def list_recent(session: AsyncSession, user_id: uuid.UUID) -> QuickFoodList:
    """Los 30 últimos alimentos distintos del usuario, por último uso (FR-001, research R1)."""
    rows = await repository.recent_entries(session, user_id, RECENT_LIMIT)
    favorites = await repository.favorite_ids(session, user_id)
    return QuickFoodList(items=[_quick_food(f, e, user_id, favorites) for e, f in rows])


@dataclass
class _Fav:
    """Lo que `order_favorites` necesita de un favorito, más el alimento y su última entrada."""

    food: Food
    entry: DiaryEntry | None

    @property
    def name(self) -> str:
        return self.food.name

    @property
    def last_used_at(self) -> datetime | None:
        return None if self.entry is None else self.entry.created_at


async def list_favorites(session: AsyncSession, user_id: uuid.UUID) -> QuickFoodList:
    """Favoritos disponibles: por último uso y, al final, los nunca usados por nombre (FR-010)."""
    rows = await repository.favorites_with_last_use(session, user_id)
    ordered = order_favorites(_Fav(food, entry) for food, entry in rows)
    return QuickFoodList(
        items=[_quick_food(f.food, f.entry, user_id, {f.food.id}) for f in ordered]
    )


async def mark_favorite(
    session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID, now: datetime
) -> None:
    """Marca un alimento disponible como favorito; si no, `FOOD_NOT_FOUND` (research R8)."""
    started = time.monotonic()
    food = await foods_repository.get_usable(session, user_id, food_id)
    if food is None:
        raise food_not_found()
    await repository.add_favorite(session, user_id, food_id, now)
    await session.commit()
    # Nunca el alimento: dice qué le gusta a una persona (research R11).
    get_logger().info(
        "favorite_added",
        user_id=str(user_id),
        duration_ms=int((time.monotonic() - started) * 1000),
    )


async def unmark_favorite(session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID) -> None:
    started = time.monotonic()
    await repository.remove_favorite(session, user_id, food_id)
    await session.commit()
    get_logger().info(
        "favorite_removed",
        user_id=str(user_id),
        duration_ms=int((time.monotonic() - started) * 1000),
    )
