"""Consentimiento de datos de salud (research R8, R9)."""

from __future__ import annotations

import uuid

import structlog
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal import clock
from mykcal.consent.models import HealthConsent
from mykcal.core.errors import ApiError, ErrorCode

# Versión vigente del texto. Debe coincidir con `consentTextVersion` de la app.
CURRENT_CONSENT_VERSION = "2026-11-1"


async def has_consent(session: AsyncSession, user_id: uuid.UUID) -> bool:
    result = await session.execute(
        select(HealthConsent.id).where(HealthConsent.user_id == user_id).limit(1)
    )
    return result.first() is not None


async def accept(session: AsyncSession, user_id: uuid.UUID, version: str) -> HealthConsent:
    """Registra el consentimiento; repetir la misma versión no crea otra fila."""
    if version != CURRENT_CONSENT_VERSION:
        raise ApiError(
            409,
            ErrorCode.CONSENT_VERSION_MISMATCH,
            "La versión del texto no es la vigente. Actualiza la app.",
        )
    await session.execute(
        insert(HealthConsent)
        .values(user_id=user_id, text_version=version, accepted_at=clock.utcnow())
        .on_conflict_do_nothing(constraint="uq_health_consent_user_version")
    )
    row = (
        await session.execute(
            select(HealthConsent).where(
                HealthConsent.user_id == user_id, HealthConsent.text_version == version
            )
        )
    ).scalar_one()
    await session.commit()
    structlog.get_logger("mykcal").info("consent_recorded")
    return row
