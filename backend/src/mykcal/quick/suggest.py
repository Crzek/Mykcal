"""Cantidad sugerida de un alimento reciente o favorito (research R2). Función pura."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

_ONE_DECIMAL = Decimal("0.1")
DEFAULT_QUANTITY = Decimal(100)


@dataclass(frozen=True)
class LastUse:
    """Cantidad de la última entrada activa del alimento."""

    quantity: Decimal
    servings: Decimal | None
    serving_size: Decimal | None  # la ración que tenía el alimento al registrarla


def _grams(servings: Decimal, serving_size: Decimal) -> Decimal:
    return (servings * serving_size).quantize(_ONE_DECIMAL, rounding=ROUND_HALF_UP)


def suggest_amount(
    last: LastUse | None, serving_size: Decimal | None
) -> tuple[Decimal, Decimal | None]:
    """Devuelve `(g/ml, raciones)` listos para `POST /v1/diary/entries`.

    1. Con uso previo en raciones y la misma ración hoy: las mismas raciones.
    2. Con uso previo en otro caso: los mismos g/ml, sin raciones.
    3. Sin uso y con ración: 1 ración (FR-004).
    4. Sin uso ni ración: 100 g/ml.
    """
    if last is not None:
        if (
            last.servings is not None
            and serving_size is not None
            and last.serving_size == serving_size
        ):
            return _grams(last.servings, serving_size), last.servings
        return last.quantity, None
    if serving_size is not None:
        return _grams(Decimal(1), serving_size), Decimal(1)
    return DEFAULT_QUANTITY, None
