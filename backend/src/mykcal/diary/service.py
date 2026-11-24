"""Lógica del diario: armar el día, crear, editar, borrar y restaurar entradas."""

from __future__ import annotations

import time
import uuid
from datetime import date, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.core.errors import ApiError, ErrorCode
from mykcal.diary import repository
from mykcal.diary.day import day_end_utc, validate_entry_date
from mykcal.diary.models import DiaryEntry
from mykcal.diary.quantity import resolve_quantity
from mykcal.diary.schemas import DiaryDay, DiaryEntryCreate, DiaryEntryUpdate
from mykcal.diary.summary import build_day
from mykcal.foods import repository as foods_repository
from mykcal.foods.nutrients import NUTRIENTS
from mykcal.foods.service import food_not_found
from mykcal.logging import get_logger
from mykcal.targets import service as targets


async def get_day(
    session: AsyncSession, user_id: uuid.UUID, day: date, utc_offset_min: int
) -> DiaryDay:
    """Día con resumen y comidas. El objetivo es el vigente al terminar ese día (FR-011)."""
    target = await targets.target_for_day(session, user_id, day_end_utc(day, utc_offset_min))
    if target is None:
        raise ApiError(404, ErrorCode.TARGET_NOT_FOUND, "Aún no tienes objetivo diario.")
    entries = await repository.entries_of_day(session, user_id, day)
    return build_day(day, target, entries)


async def create_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    registered_at: datetime,
    data: DiaryEntryCreate,
    utc_offset_min: int,
    now: datetime,
) -> DiaryDay:
    """Añade un alimento a una comida copiando su nombre y valores por 100 (FR-002–FR-004).

    Un alimento no disponible para el usuario (ajeno, eliminado o archivado) es `FOOD_NOT_FOUND`.
    """
    started = time.monotonic()
    validate_entry_date(data.date, registered_at, now)
    food = await foods_repository.get_visible(session, user_id, data.food_id)
    if food is None or (food.kind == "generic" and food.archived_at is not None):
        raise food_not_found()
    quantity, servings = resolve_quantity(data.quantity, data.servings, food.serving_size)
    repository.add_entry(
        session,
        DiaryEntry(
            id=uuid.uuid4(),
            user_id=user_id,
            entry_date=data.date,
            meal=data.meal,
            food_id=food.id,
            food_kind=food.kind,
            food_name=food.name,
            food_brand=food.brand,
            base_unit=food.base_unit,
            serving_size=food.serving_size,
            quantity=quantity,
            servings=servings,
            created_at=now,
            updated_at=now,
            **{name: getattr(food, name) for name in NUTRIENTS},
        ),
    )
    await session.flush()
    day = await get_day(session, user_id, data.date, utc_offset_min)
    await session.commit()
    # Nunca el alimento, la cantidad ni la fecha: dicen qué come una persona (research R12).
    get_logger().info(
        "diary_entry_created",
        user_id=str(user_id),
        meal=data.meal,
        duration_ms=int((time.monotonic() - started) * 1000),
    )
    return day


async def view_day(
    session: AsyncSession,
    user_id: uuid.UUID,
    registered_at: datetime,
    day: date,
    utc_offset_min: int,
    now: datetime,
) -> DiaryDay:
    """`get_day` de una petición: antes comprueba que la fecha esté en el rango del diario."""
    validate_entry_date(day, registered_at, now)
    return await get_day(session, user_id, day, utc_offset_min)


RESTORE_WINDOW = timedelta(seconds=60)


def entry_not_found() -> ApiError:
    """Mismo cuerpo para una entrada inexistente, borrada o de otro usuario (research R11)."""
    return ApiError(404, ErrorCode.ENTRY_NOT_FOUND, "Entrada no encontrada.")


def _log(event: str, user_id: uuid.UUID, meal: str, started: float) -> None:
    # Nunca el alimento, la cantidad ni la fecha: dicen qué come una persona (research R12).
    get_logger().info(
        event,
        user_id=str(user_id),
        meal=meal,
        duration_ms=int((time.monotonic() - started) * 1000),
    )


async def update_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    entry_id: uuid.UUID,
    data: DiaryEntryUpdate,
    utc_offset_min: int,
    now: datetime,
) -> DiaryDay:
    """Cambia la cantidad o la comida de una entrada sin tocar su copia del alimento (FR-005)."""
    started = time.monotonic()
    if data.meal is None and data.quantity is None and data.servings is None:
        raise ApiError(
            400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=["quantity", "servings"]
        )
    entry = await repository.get_entry(session, user_id, entry_id)
    if entry is None:
        raise entry_not_found()
    if data.quantity is not None or data.servings is not None:
        # La ración es la de la copia de la entrada, no la del alimento actual (research R5).
        quantity, servings = resolve_quantity(data.quantity, data.servings, entry.serving_size)
        entry.quantity = quantity
        entry.servings = servings
    if data.meal is not None:
        entry.meal = data.meal
    entry.updated_at = now
    await session.flush()
    day = await get_day(session, user_id, entry.entry_date, utc_offset_min)
    await session.commit()
    _log("diary_entry_updated", user_id, entry.meal, started)
    return day


async def delete_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    entry_id: uuid.UUID,
    utc_offset_min: int,
    now: datetime,
) -> DiaryDay:
    """Borra la entrada (borrado lógico) y devuelve el día sin ella."""
    started = time.monotonic()
    entry = await repository.get_entry(session, user_id, entry_id)
    if entry is None:
        raise entry_not_found()
    entry.deleted_at = now
    entry.updated_at = now
    await session.flush()
    day = await get_day(session, user_id, entry.entry_date, utc_offset_min)
    await session.commit()
    _log("diary_entry_deleted", user_id, entry.meal, started)
    return day


async def restore_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    entry_id: uuid.UUID,
    utc_offset_min: int,
    now: datetime,
) -> DiaryDay:
    """Deshace un borrado hecho hace 60 s o menos, con los mismos valores (US3.4)."""
    started = time.monotonic()
    entry = await repository.get_entry(session, user_id, entry_id, deleted=True)
    if entry is None or entry.deleted_at is None or now - entry.deleted_at > RESTORE_WINDOW:
        raise entry_not_found()
    entry.deleted_at = None
    entry.updated_at = now
    await session.flush()
    day = await get_day(session, user_id, entry.entry_date, utc_offset_min)
    await session.commit()
    _log("diary_entry_restored", user_id, entry.meal, started)
    return day
