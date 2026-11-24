"""Versiones del objetivo diario (research R4, R5, R12, R13)."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

import structlog
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.targets.calc import CalcInputs, CalcResult, calculate
from mykcal.targets.models import TARGET_RANGES, DailyTarget
from mykcal.targets.schemas import Calculation, TargetValues
from mykcal.targets.schemas import DailyTarget as DailyTargetOut


@dataclass(frozen=True)
class CalcData:
    """Datos con los que se calculó el objetivo (FR-013)."""

    weight_kg: Decimal
    age: int
    sex: str
    height_cm: int
    activity_level: str
    goal: str

    def inputs(self) -> CalcInputs:
        return CalcInputs(
            sex=self.sex,
            age=self.age,
            height_cm=self.height_cm,
            weight_kg=self.weight_kg,
            activity_level=self.activity_level,
            goal=self.goal,
        )


def values_from_result(result: CalcResult) -> TargetValues:
    return TargetValues(**{name: getattr(result, name) for name in TARGET_RANGES})


async def current_target(session: AsyncSession, user_id: uuid.UUID) -> DailyTarget | None:
    result = await session.execute(
        select(DailyTarget).where(DailyTarget.user_id == user_id, DailyTarget.is_current.is_(True))
    )
    return result.scalar_one_or_none()


async def target_for_day(
    session: AsyncSession, user_id: uuid.UUID, day_end_utc: datetime
) -> DailyTarget | None:
    """Versión del objetivo vigente al terminar un día (diario, research R3).

    Usa el índice `ix_daily_target_user_effective`. Un usuario tiene unas pocas versiones.
    """
    from mykcal.diary.day import pick_target

    rows = await session.execute(select(DailyTarget).where(DailyTarget.user_id == user_id))
    return pick_target(rows.scalars().all(), day_end_utc)


async def save_version(
    session: AsyncSession,
    user_id: uuid.UUID,
    values: TargetValues,
    source: str,
    calc: CalcData,
    calculated_at: datetime,
    notices: list[str],
    now: datetime,
) -> DailyTarget:
    """Cierra la versión vigente e inserta la nueva. No hace commit (lo hace quien llama)."""
    await session.execute(
        update(DailyTarget)
        .where(DailyTarget.user_id == user_id, DailyTarget.is_current.is_(True))
        .values(is_current=False, superseded_at=now)
    )
    await session.flush()
    row = DailyTarget(
        user_id=user_id,
        is_current=True,
        effective_from=now,
        source=source,
        **values.model_dump(),
        calc_weight_kg=calc.weight_kg,
        calc_age=calc.age,
        calc_sex=calc.sex,
        calc_height_cm=calc.height_cm,
        calc_activity=calc.activity_level,
        calc_goal=calc.goal,
        calculated_at=calculated_at,
        calc_notices=list(notices),
    )
    session.add(row)
    await session.flush()
    structlog.get_logger("mykcal").info("target_saved", source=source)
    return row


async def save_calculated(
    session: AsyncSession, user_id: uuid.UUID, calc: CalcData, now: datetime
) -> DailyTarget:
    result = calculate(calc.inputs())
    return await save_version(
        session, user_id, values_from_result(result), "calculated", calc, now, result.notices, now
    )


def calc_data_of(row: DailyTarget) -> CalcData:
    return CalcData(
        weight_kg=row.calc_weight_kg,
        age=row.calc_age,
        sex=row.calc_sex,
        height_cm=row.calc_height_cm,
        activity_level=row.calc_activity,
        goal=row.calc_goal,
    )


def needs_recalc(
    current: DailyTarget, submitted: CalcData, previous_weight: Decimal | None
) -> bool:
    """True si el perfil enviado difiere de los `calc_*` vigentes o el peso del último registro.

    Research R12.
    """
    base = calc_data_of(current)
    profile_changed = (
        submitted.age,
        submitted.sex,
        submitted.height_cm,
        submitted.activity_level,
        submitted.goal,
    ) != (base.age, base.sex, base.height_cm, base.activity_level, base.goal)
    weight_changed = previous_weight is None or Decimal(submitted.weight_kg) != Decimal(
        previous_weight
    )
    return profile_changed or weight_changed


def to_out(row: DailyTarget) -> DailyTargetOut:
    return DailyTargetOut(
        values=TargetValues.model_validate(row),
        source=row.source,  # type: ignore[arg-type]
        effective_from=row.effective_from,
        calculation=Calculation(
            weight_kg=float(row.calc_weight_kg),
            age=row.calc_age,
            sex=row.calc_sex,  # type: ignore[arg-type]
            height_cm=row.calc_height_cm,
            activity_level=row.calc_activity,  # type: ignore[arg-type]
            goal=row.calc_goal,  # type: ignore[arg-type]
            calculated_at=row.calculated_at,
            notices=list(row.calc_notices),  # type: ignore[arg-type]
        ),
    )


async def recalculate(
    session: AsyncSession,
    user_id: uuid.UUID,
    profile: CalcData,
    now: datetime | None = None,
) -> DailyTarget:
    """Calcula con el perfil dado (el peso va en `profile.weight_kg`) y guarda `calculated`."""
    return await save_calculated(session, user_id, profile, now or clock.utcnow())


async def save_manual(
    session: AsyncSession, user_id: uuid.UUID, values: TargetValues, now: datetime
) -> DailyTarget:
    current = await current_target(session, user_id)
    if current is None:
        raise ApiError(409, ErrorCode.PROFILE_REQUIRED, "Completa tu perfil primero.")
    return await save_version(
        session,
        user_id,
        values,
        "manual",
        calc_data_of(current),
        current.calculated_at,
        list(current.calc_notices),
        now,
    )
