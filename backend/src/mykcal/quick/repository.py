"""Consultas de recientes y favoritos. Todo recibe `user_id` (principio V)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import distinct_on, insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from mykcal.diary.models import DiaryEntry
from mykcal.foods.models import Food
from mykcal.foods.repository import usable_food
from mykcal.quick.models import FavoriteFood


def _last_entry_per_food(user_id: uuid.UUID):
    """Subconsulta: la última entrada activa de cada alimento del usuario (research R1)."""
    return (
        select(DiaryEntry)
        .where(DiaryEntry.user_id == user_id, DiaryEntry.deleted_at.is_(None))
        .ext(distinct_on(DiaryEntry.food_id))
        .order_by(DiaryEntry.food_id, DiaryEntry.created_at.desc(), DiaryEntry.id.desc())
        .subquery()
    )


async def recent_entries(
    session: AsyncSession, user_id: uuid.UUID, limit: int
) -> list[tuple[DiaryEntry, Food]]:
    """Última entrada y alimento de los `limit` alimentos distintos más recientes.

    Descarta los alimentos que ya no se pueden registrar antes de cortar, así que devuelve hasta
    `limit` válidos.
    """
    last = aliased(DiaryEntry, _last_entry_per_food(user_id))
    stmt = (
        select(last, Food)
        .join(Food, Food.id == last.food_id)
        .where(usable_food(user_id))
        .order_by(last.created_at.desc(), last.id.desc())
        .limit(limit)
    )
    return [(row[0], row[1]) for row in (await session.execute(stmt)).all()]


async def favorite_ids(session: AsyncSession, user_id: uuid.UUID) -> set[uuid.UUID]:
    stmt = select(FavoriteFood.food_id).where(FavoriteFood.user_id == user_id)
    return set((await session.execute(stmt)).scalars().all())


async def favorites_with_last_use(
    session: AsyncSession, user_id: uuid.UUID
) -> list[tuple[Food, DiaryEntry | None]]:
    """Favoritos disponibles con su última entrada activa, si la hay."""
    last = aliased(DiaryEntry, _last_entry_per_food(user_id))
    stmt = (
        select(Food, last)
        .select_from(FavoriteFood)
        .join(Food, Food.id == FavoriteFood.food_id)
        .outerjoin(last, last.food_id == Food.id)
        .where(FavoriteFood.user_id == user_id, usable_food(user_id))
    )
    return [(row[0], row[1]) for row in (await session.execute(stmt)).all()]


async def add_favorite(
    session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID, now: datetime
) -> None:
    """Idempotente: marcar dos veces no duplica."""
    stmt = (
        insert(FavoriteFood)
        .values(user_id=user_id, food_id=food_id, created_at=now)
        .on_conflict_do_nothing(index_elements=[FavoriteFood.user_id, FavoriteFood.food_id])
    )
    await session.execute(stmt)


async def remove_favorite(session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID) -> None:
    """Idempotente: desmarcar uno que no lo era no hace nada."""
    await session.execute(
        delete(FavoriteFood).where(FavoriteFood.user_id == user_id, FavoriteFood.food_id == food_id)
    )
