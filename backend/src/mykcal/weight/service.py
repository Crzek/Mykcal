"""Registros de peso, gráfica y propuesta de recálculo (research R2–R8)."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from typing import Literal

import structlog
from sqlalchemy import delete, select, text, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.accounts.models import UserAccount
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.profile import service as profile
from mykcal.profile.models import WeightEntry
from mykcal.targets import service as targets
from mykcal.targets.calc import calculate
from mykcal.targets.models import DailyTarget
from mykcal.targets.schemas import TargetValues
from mykcal.weight import schemas
from mykcal.weight.average import (
    exceeds_threshold,
    is_large_change,
    moving_average_series,
    weekly_average,
)
from mykcal.weight.models import RecalcProposal

IGNORE_DAYS = 7
PERIOD_DAYS = {"p30": 29, "p90": 89, "all": None}


def local_today(now: datetime, utc_offset_min: int) -> date:
    """«Hoy» en la zona del móvil: `(ahora UTC + desfase).date()` (research R2)."""
    return (now + timedelta(minutes=utc_offset_min)).date()


def validate_measured_on(
    day: date, registered_at: datetime, now: datetime, utc_offset_min: int
) -> None:
    """Fecha del registro: no posterior a hoy (local) ni anterior al alta − 1 día (FR-001)."""
    earliest = registered_at.astimezone(UTC).date() - timedelta(days=1)
    if day > local_today(now, utc_offset_min) or day < earliest:
        raise ApiError(
            400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=["measured_on"]
        )


def _entry_out(row: WeightEntry) -> schemas.WeightEntry:
    return schemas.WeightEntry(
        measured_on=row.measured_on, weight_kg=float(row.weight_kg), updated_at=row.updated_at
    )


async def _all_entries(session: AsyncSession, user_id: uuid.UUID) -> list[tuple[date, Decimal]]:
    rows = await session.execute(
        select(WeightEntry.measured_on, WeightEntry.weight_kg).where(WeightEntry.user_id == user_id)
    )
    return [(day, kg) for day, kg in rows.all()]


async def list_entries(
    session: AsyncSession, user_id: uuid.UUID, date_from: date | None, date_to: date | None
) -> schemas.WeightList:
    query = select(WeightEntry).where(WeightEntry.user_id == user_id)
    if date_from is not None:
        query = query.where(WeightEntry.measured_on >= date_from)
    if date_to is not None:
        query = query.where(WeightEntry.measured_on <= date_to)
    rows = await session.execute(query.order_by(WeightEntry.measured_on.desc()))
    return schemas.WeightList(entries=[_entry_out(r) for r in rows.scalars()])


async def upsert_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    account: UserAccount,
    data: schemas.WeightInput,
    now: datetime,
    utc_offset_min: int,
) -> schemas.WeightEntry:
    validate_measured_on(data.measured_on, account.created_at, now, utc_offset_min)
    result = await session.execute(
        insert(WeightEntry)
        .values(
            user_id=user_id,
            measured_on=data.measured_on,
            weight_kg=data.weight_kg,
            created_at=now,
            updated_at=now,
        )
        .on_conflict_do_update(
            constraint="uq_weight_entry_user_day",
            set_={"weight_kg": data.weight_kg, "updated_at": now},
        )
        .returning(WeightEntry)
    )
    row = result.scalar_one()
    await evaluate_proposal(session, user_id, local_today(now, utc_offset_min), now)
    structlog.get_logger("mykcal").info("weight_saved")
    return _entry_out(row)


async def _existing(session: AsyncSession, user_id: uuid.UUID, day: date) -> WeightEntry:
    row = (
        await session.execute(
            select(WeightEntry).where(
                WeightEntry.user_id == user_id, WeightEntry.measured_on == day
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise ApiError(404, ErrorCode.WEIGHT_NOT_FOUND, "No hay peso registrado ese día.")
    return row


async def update_entry(
    session: AsyncSession,
    user_id: uuid.UUID,
    day: date,
    data: schemas.WeightUpdate,
    now: datetime,
    utc_offset_min: int,
) -> schemas.WeightEntry:
    row = await _existing(session, user_id, day)
    row.weight_kg = data.weight_kg
    row.updated_at = now
    await session.flush()
    await evaluate_proposal(session, user_id, local_today(now, utc_offset_min), now)
    structlog.get_logger("mykcal").info("weight_saved")
    return _entry_out(row)


async def delete_entry(
    session: AsyncSession, user_id: uuid.UUID, day: date, now: datetime, utc_offset_min: int
) -> None:
    row = await _existing(session, user_id, day)
    await session.delete(row)
    await session.flush()
    await evaluate_proposal(session, user_id, local_today(now, utc_offset_min), now)
    structlog.get_logger("mykcal").info("weight_deleted")


async def chart(
    session: AsyncSession,
    user_id: uuid.UUID,
    period: Literal["p30", "p90", "all"],
    today: date,
) -> schemas.WeightChart:
    span = PERIOD_DAYS[period]
    since = today - timedelta(days=span) if span is not None else None
    entries = await _all_entries(session, user_id)
    series = [p for p in moving_average_series(entries, since) if p[0] <= today]
    points = [
        schemas.WeightChartPoint(
            date=day, weight_kg=float(kg), average_kg=None if avg is None else float(avg)
        )
        for day, kg, avg in series
    ]
    weekly = weekly_average(entries, today)
    summary = schemas.WeightChartSummary(
        count=len(points),
        current_weight_kg=points[-1].weight_kg if points else None,
        weekly_average_kg=None if weekly is None else float(weekly),
        change_kg=round(points[-1].weight_kg - points[0].weight_kg, 1)
        if len(points) >= 2
        else None,
    )
    return schemas.WeightChart(period=period, points=points, summary=summary)


async def _pending(session: AsyncSession, user_id: uuid.UUID) -> RecalcProposal | None:
    return (
        await session.execute(
            select(RecalcProposal).where(
                RecalcProposal.user_id == user_id, RecalcProposal.status == "pending"
            )
        )
    ).scalar_one_or_none()


async def evaluate_proposal(
    session: AsyncSession, user_id: uuid.UUID, today: date, now: datetime
) -> RecalcProposal | None:
    """Reevalúa el umbral y deja a lo sumo una propuesta `pending` (research R5)."""
    current = await targets.current_target(session, user_id)
    if current is None:
        return None
    average = weekly_average(await _all_entries(session, user_id), today)
    if average is None or not exceeds_threshold(average, current.calc_weight_kg):
        await session.execute(
            delete(RecalcProposal).where(
                RecalcProposal.user_id == user_id, RecalcProposal.status == "pending"
            )
        )
        return None
    fields = {
        "reference_weight_kg": current.calc_weight_kg,
        "weekly_average_kg": average,
        "target_from_id": current.id,
        "was_manual": current.source == "manual",
    }
    pending = await _pending(session, user_id)
    if pending is not None:
        await session.execute(
            update(RecalcProposal).where(RecalcProposal.id == pending.id).values(**fields)
        )
        await session.refresh(pending)
        return pending
    blocked = (
        await session.execute(
            select(RecalcProposal.id).where(
                RecalcProposal.user_id == user_id,
                RecalcProposal.status == "ignored",
                RecalcProposal.ignored_until > today,
            )
        )
    ).first()
    if blocked is not None:
        return None
    row = (
        await session.execute(
            insert(RecalcProposal)
            .values(user_id=user_id, status="pending", created_at=now, **fields)
            .on_conflict_do_update(
                index_elements=["user_id"],
                index_where=text("status = 'pending'"),
                set_=fields,
            )
            .returning(RecalcProposal)
        )
    ).scalar_one()
    await session.refresh(row)
    structlog.get_logger("mykcal").info("recalc_proposed")
    return row


async def proposal_out(
    session: AsyncSession, user_id: uuid.UUID, row: RecalcProposal | None
) -> schemas.RecalcProposal:
    if row is None:
        return schemas.RecalcProposal(status="none")
    current = await targets.current_target(session, user_id)
    assert current is not None
    data = await profile.calc_data_now(session, user_id, weight_kg=row.weekly_average_kg)
    return schemas.RecalcProposal(
        status="pending",
        reference_weight_kg=float(row.reference_weight_kg),
        weekly_average_kg=float(row.weekly_average_kg),
        was_manual=row.was_manual,
        large_change=is_large_change(row.weekly_average_kg, row.reference_weight_kg),
        current=TargetValues.model_validate(current),
        proposed=targets.values_from_result(calculate(data.inputs())),
    )


async def get_proposal(
    session: AsyncSession, user_id: uuid.UUID, today: date, now: datetime
) -> schemas.RecalcProposal:
    row = await evaluate_proposal(session, user_id, today, now)
    return await proposal_out(session, user_id, row)


def _no_proposal() -> ApiError:
    return ApiError(409, ErrorCode.RECALC_NO_PROPOSAL, "No hay ninguna propuesta pendiente.")


async def accept_proposal(
    session: AsyncSession, user_id: uuid.UUID, today: date, now: datetime
) -> DailyTarget:
    row = await evaluate_proposal(session, user_id, today, now)
    if row is None:
        raise _no_proposal()
    data = await profile.calc_data_now(session, user_id, weight_kg=row.weekly_average_kg)
    target = await targets.recalculate(session, user_id, data, now)
    await session.execute(
        update(RecalcProposal)
        .where(RecalcProposal.id == row.id)
        .values(status="accepted", responded_at=now)
    )
    structlog.get_logger("mykcal").info("recalc_accepted")
    return target


async def ignore_proposal(
    session: AsyncSession, user_id: uuid.UUID, today: date, now: datetime
) -> None:
    row = await evaluate_proposal(session, user_id, today, now)
    if row is None:
        raise _no_proposal()
    await session.execute(
        update(RecalcProposal)
        .where(RecalcProposal.id == row.id)
        .values(
            status="ignored", responded_at=now, ignored_until=today + timedelta(days=IGNORE_DAYS)
        )
    )
    structlog.get_logger("mykcal").info("recalc_ignored")
