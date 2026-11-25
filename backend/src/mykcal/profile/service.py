"""Perfil, peso y objetivo inicial o recalculado (research R6, R11, R12)."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal

import structlog
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.core.errors import ApiError, ErrorCode
from mykcal.profile.models import UserProfile, WeightEntry
from mykcal.profile.schemas import Profile, ProfileInput, ProfileSaved, Recalculation
from mykcal.targets import service as targets
from mykcal.targets.calc import calculate
from mykcal.targets.service import CalcData


async def latest_weight(session: AsyncSession, user_id: uuid.UUID) -> WeightEntry | None:
    result = await session.execute(
        select(WeightEntry)
        .where(WeightEntry.user_id == user_id)
        .order_by(WeightEntry.measured_on.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def get_profile(session: AsyncSession, user_id: uuid.UUID) -> Profile:
    row = (
        await session.execute(select(UserProfile).where(UserProfile.user_id == user_id))
    ).scalar_one_or_none()
    weight = await current_weight(session, user_id)
    if row is None or weight is None:
        raise ApiError(404, ErrorCode.PROFILE_NOT_FOUND, "Aún no has completado tu perfil.")
    return _profile_out(row, *weight)


async def current_weight(session: AsyncSession, user_id: uuid.UUID) -> tuple[Decimal, date] | None:
    """Último peso; sin registros (se pudo borrar el único), el del objetivo vigente."""
    latest = await latest_weight(session, user_id)
    if latest is not None:
        return latest.weight_kg, latest.measured_on
    target = await targets.current_target(session, user_id)
    if target is None:
        return None
    return target.calc_weight_kg, target.calculated_at.date()


def _profile_out(row: UserProfile, weight_kg: Decimal, measured_on: date) -> Profile:
    return Profile(
        age=row.age,
        sex=row.sex,  # type: ignore[arg-type]
        height_cm=row.height_cm,
        weight_kg=float(weight_kg),
        weight_measured_on=measured_on,
        activity_level=row.activity_level,  # type: ignore[arg-type]
        goal=row.goal,  # type: ignore[arg-type]
        updated_at=row.updated_at,
    )


async def save_profile(
    session: AsyncSession, user_id: uuid.UUID, data: ProfileInput, now: datetime
) -> ProfileSaved:
    """Guarda perfil y peso y crea, recalcula o propone el objetivo en una transacción."""
    if data.measured_on > (now + timedelta(days=1)).date():
        raise ApiError(
            400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=["measured_on"]
        )
    previous = await latest_weight(session, user_id)
    previous_weight = previous.weight_kg if previous is not None else None

    profile_values = {
        "age": data.age,
        "sex": data.sex,
        "height_cm": data.height_cm,
        "activity_level": data.activity_level,
        "goal": data.goal,
        "updated_at": now,
    }
    await session.execute(
        insert(UserProfile)
        .values(user_id=user_id, created_at=now, **profile_values)
        .on_conflict_do_update(index_elements=["user_id"], set_=profile_values)
    )
    await session.execute(
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
    )
    submitted = CalcData(
        weight_kg=data.weight_kg,
        age=data.age,
        sex=data.sex,
        height_cm=data.height_cm,
        activity_level=data.activity_level,
        goal=data.goal,
    )
    current = await targets.current_target(session, user_id)
    if current is None:
        target = await targets.save_calculated(session, user_id, submitted, now)
        recalculation = Recalculation(status="created")
    elif not targets.needs_recalc(current, submitted, previous_weight):
        target, recalculation = current, Recalculation(status="none")
    elif current.source == "calculated":
        before = targets.TargetValues.model_validate(current)
        target = await targets.save_calculated(session, user_id, submitted, now)
        recalculation = Recalculation(status="applied", previous=before)
    else:  # objetivo editado a mano: solo se propone, no se guarda (FR-015)
        proposal = targets.values_from_result(calculate(submitted.inputs()))
        target, recalculation = current, Recalculation(status="proposed", proposed=proposal)

    weight = await latest_weight(session, user_id)
    row = (
        await session.execute(select(UserProfile).where(UserProfile.user_id == user_id))
    ).scalar_one()
    assert weight is not None
    structlog.get_logger("mykcal").info("profile_saved")
    return ProfileSaved(
        profile=_profile_out(row, weight.weight_kg, weight.measured_on),
        target=targets.to_out(target),
        recalculation=recalculation,
    )


async def calc_data_now(
    session: AsyncSession, user_id: uuid.UUID, weight_kg: Decimal | None = None
) -> CalcData:
    """Perfil actual + el peso dado o el del último registro (para `recalculate`)."""
    row = (
        await session.execute(select(UserProfile).where(UserProfile.user_id == user_id))
    ).scalar_one_or_none()
    weight = await current_weight(session, user_id)
    if row is None or weight is None:
        raise ApiError(409, ErrorCode.PROFILE_REQUIRED, "Completa tu perfil primero.")
    return CalcData(
        weight_kg=weight_kg if weight_kg is not None else weight[0],
        age=row.age,
        sex=row.sex,
        height_cm=row.height_cm,
        activity_level=row.activity_level,
        goal=row.goal,
    )
