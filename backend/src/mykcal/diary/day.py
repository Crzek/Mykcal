"""Fecha del día y objetivo vigente en él. Funciones puras (research R1, R3)."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import UTC, date, datetime, timedelta
from typing import Protocol

from mykcal.core.errors import ApiError, ErrorCode


class _Versioned(Protocol):
    effective_from: datetime


def day_end_utc(day: date, utc_offset_min: int) -> datetime:
    """Instante UTC en que termina `day` en la zona del móvil.

    `utc_offset_min` es el desfase de esa zona al final de ese día: la medianoche local
    (día siguiente, 00:00) es `00:00 UTC − desfase`.
    """
    midnight_utc = datetime(day.year, day.month, day.day, tzinfo=UTC) + timedelta(days=1)
    return midnight_utc - timedelta(minutes=utc_offset_min)


def pick_target[V: _Versioned](versions: Iterable[V], day_end: datetime) -> V | None:
    """Versión del objetivo vigente al terminar el día.

    Es la más reciente con `effective_from < day_end`. Si todas son posteriores (días entre el
    alta y el primer objetivo), la más antigua. Sin versiones, `None`.
    """
    ordered = sorted(versions, key=lambda v: v.effective_from)
    if not ordered:
        return None
    before = [v for v in ordered if v.effective_from < day_end]
    return before[-1] if before else ordered[0]


def validate_entry_date(day: date, registered_at: datetime, now: datetime) -> None:
    """Rechaza fechas absurdas con un día de margen por la zona horaria (research R1).

    Máximo: hoy en UTC + 1 día. Mínimo: la fecha UTC del alta − 1 día. El límite exacto lo aplica
    la app, que conoce el día local.
    """
    latest = now.astimezone(UTC).date() + timedelta(days=1)
    earliest = registered_at.astimezone(UTC).date() - timedelta(days=1)
    if not earliest <= day <= latest:
        raise ApiError(
            400,
            ErrorCode.DIARY_DATE_OUT_OF_RANGE,
            "Esa fecha está fuera del rango del diario.",
        )
