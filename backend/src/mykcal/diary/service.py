"""Lógica del diario: armar el día, crear, editar, borrar y restaurar entradas."""

from __future__ import annotations

import time
import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.core.errors import ApiError, ErrorCode
from mykcal.diary import repository
from mykcal.diary.copy_rules import copied_values, copy_window, order_meals, source_in_window
from mykcal.diary.day import day_end_utc, validate_entry_date
from mykcal.diary.models import DiaryEntry
from mykcal.diary.quantity import resolve_quantity
from mykcal.diary.schemas import (
    CopySourceDay,
    CopySourceEntry,
    CopySourceList,
    CopySourceMeal,
    DiaryCopyCreate,
    DiaryCopyResult,
    DiaryDay,
    DiaryEntryCreate,
    DiaryEntryUpdate,
)
from mykcal.diary.summary import build_day, entry_values, round_nutrient
from mykcal.foods import repository as foods_repository
from mykcal.foods.models import Food
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
) -> tuple[DiaryDay, uuid.UUID]:
    """Añade un alimento a una comida copiando su nombre y valores por 100 (FR-002–FR-004).

    Devuelve el día y el id de la entrada creada (cabecera `Location`, research R3).
    Un alimento no disponible para el usuario (ajeno, eliminado o archivado) es `FOOD_NOT_FOUND`.
    """
    started = time.monotonic()
    validate_entry_date(data.date, registered_at, now)
    food = await foods_repository.get_visible(session, user_id, data.food_id)
    if food is None or (food.kind == "generic" and food.archived_at is not None):
        raise food_not_found()
    quantity, servings = resolve_quantity(data.quantity, data.servings, food.serving_size)
    entry_id = uuid.uuid4()
    repository.add_entry(
        session,
        DiaryEntry(
            id=entry_id,
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
    return day, entry_id


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


def copy_not_found() -> ApiError:
    """Mismo cuerpo para una copia inexistente, ajena, ya deshecha o fuera de plazo (R10)."""
    return ApiError(404, ErrorCode.COPY_NOT_FOUND, "Copia no encontrada.")


async def _usable_foods(
    session: AsyncSession, user_id: uuid.UUID, food_ids: set[uuid.UUID]
) -> dict[uuid.UUID, Food]:
    """Alimentos de la lista que el usuario aún puede registrar. Los demás no están en el mapa."""
    found = {}
    for food_id in food_ids:
        food = await foods_repository.get_usable(session, user_id, food_id)
        if food is not None:
            found[food_id] = food
    return found


async def copy_meal(
    session: AsyncSession,
    user_id: uuid.UUID,
    registered_at: datetime,
    data: DiaryCopyCreate,
    utc_offset_min: int,
    now: datetime,
) -> DiaryCopyResult:
    """Copia todas las entradas de una comida a otra comida de otro día, de una sola vez.

    Cada copia es una entrada nueva con los valores actuales del alimento, o los de la entrada
    si el alimento ya no existe (FR-006). Todas comparten un `copy_id` para deshacerlas juntas.
    """
    started = time.monotonic()
    validate_entry_date(data.target_date, registered_at, now)
    if not source_in_window(data.source_date, data.target_date):
        raise ApiError(
            400, ErrorCode.DIARY_DATE_OUT_OF_RANGE, "Esa fecha está fuera del rango del diario."
        )
    sources = await repository.entries_of_meal(session, user_id, data.source_date, data.source_meal)
    if not sources:
        raise ApiError(400, ErrorCode.COPY_SOURCE_EMPTY, "Esa comida no tiene alimentos.")
    foods = await _usable_foods(session, user_id, {e.food_id for e in sources})
    copy_id = uuid.uuid4()
    entry_ids: list[uuid.UUID] = []
    for i, source in enumerate(sources):
        entry_id = uuid.uuid4()
        entry_ids.append(entry_id)
        # Un microsegundo de diferencia por entrada: el día las ordena por `created_at`.
        stamp = now + timedelta(microseconds=i)
        repository.add_entry(
            session,
            DiaryEntry(
                id=entry_id,
                user_id=user_id,
                entry_date=data.target_date,
                meal=data.target_meal,
                food_id=source.food_id,
                food_kind=source.food_kind,
                copy_id=copy_id,
                created_at=stamp,
                updated_at=stamp,
                **copied_values(source, foods.get(source.food_id)),
            ),
        )
    await session.flush()
    day = await get_day(session, user_id, data.target_date, utc_offset_min)
    await session.commit()
    # Nunca alimentos, cantidades ni fechas (research R11).
    get_logger().info(
        "diary_meal_copied",
        user_id=str(user_id),
        source_meal=data.source_meal,
        target_meal=data.target_meal,
        entries_count=len(entry_ids),
        duration_ms=int((time.monotonic() - started) * 1000),
    )
    return DiaryCopyResult(copy_id=copy_id, entry_ids=entry_ids, day=day)


async def undo_copy(
    session: AsyncSession,
    user_id: uuid.UUID,
    copy_id: uuid.UUID,
    utc_offset_min: int,
    now: datetime,
) -> DiaryDay:
    """Borra las entradas de una copia hecha hace 60 s o menos; las demás no se tocan (US3.5)."""
    started = time.monotonic()
    entries = await repository.entries_of_copy(session, user_id, copy_id)
    if not entries or now - min(e.created_at for e in entries) > RESTORE_WINDOW:
        raise copy_not_found()
    for entry in entries:
        entry.deleted_at = now
        entry.updated_at = now
    await session.flush()
    day = await get_day(session, user_id, entries[0].entry_date, utc_offset_min)
    await session.commit()
    get_logger().info(
        "diary_copy_undone",
        user_id=str(user_id),
        entries_count=len(entries),
        duration_ms=int((time.monotonic() - started) * 1000),
    )
    return day


def _values_changed(entry: DiaryEntry, food: Food | None) -> bool:
    """El alimento disponible tiene hoy otros valores por 100 que la copia de la entrada."""
    if food is None:
        return False
    return any(getattr(entry, n) != getattr(food, n) for n in NUTRIENTS)


async def copy_sources(
    session: AsyncSession,
    user_id: uuid.UUID,
    registered_at: datetime,
    target_date: date,
    target_meal: str,
    now: datetime,
) -> CopySourceList:
    """Comidas con entradas de los 14 días anteriores al destino, del día más reciente al más
    antiguo, con la del mismo tipo que `target_meal` primero (FR-005, research R7)."""
    validate_entry_date(target_date, registered_at, now)
    first, last = copy_window(target_date)
    entries = await repository.entries_in_range(session, user_id, first, last)
    foods = await _usable_foods(session, user_id, {e.food_id for e in entries})
    by_day: dict[date, dict[str, list[DiaryEntry]]] = defaultdict(lambda: defaultdict(list))
    for entry in entries:
        by_day[entry.entry_date][entry.meal].append(entry)
    days = []
    for day in sorted(by_day, reverse=True):
        meals = []
        for meal in order_meals(by_day[day], target_meal):
            in_meal = by_day[day][meal]
            kcal = sum((entry_values(e)["kcal"] for e in in_meal), start=Decimal(0))
            meals.append(
                CopySourceMeal(
                    meal=meal,  # type: ignore[arg-type]
                    entries=[
                        CopySourceEntry(
                            food_name=e.food_name,
                            food_brand=e.food_brand,
                            base_unit=e.base_unit,  # type: ignore[arg-type]
                            quantity=float(e.quantity),
                            servings=None if e.servings is None else float(e.servings),
                            kcal=float(round_nutrient("kcal", entry_values(e)["kcal"])),
                        )
                        for e in in_meal
                    ],
                    kcal=float(round_nutrient("kcal", kcal)),
                    values_changed=any(_values_changed(e, foods.get(e.food_id)) for e in in_meal),
                )
            )
        days.append(CopySourceDay(date=day, meals=meals))
    return CopySourceList(days=days)
