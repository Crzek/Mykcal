"""Media semanal y umbral del recálculo: funciones puras (research R3, FR-004, FR-009).

Sin E/S, sin reloj y sin `float`. Un único valor redondeado (1 decimal, medio hacia arriba) es el
que se compara, se muestra y se usa para recalcular.
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

WINDOW_DAYS = 7
MIN_ENTRIES = 3
THRESHOLD = Decimal("0.02")
LARGE_CHANGE = Decimal("0.10")
_ONE_DECIMAL = Decimal("0.1")

Entry = tuple[date, Decimal]


def _window_average(entries: Iterable[Entry], as_of: date) -> Decimal | None:
    start = as_of - timedelta(days=WINDOW_DAYS - 1)
    weights = [Decimal(kg) for day, kg in entries if start <= day <= as_of]
    if len(weights) < MIN_ENTRIES:
        return None
    return (sum(weights, Decimal(0)) / len(weights)).quantize(_ONE_DECIMAL, rounding=ROUND_HALF_UP)


def weekly_average(entries: Iterable[Entry], as_of: date) -> Decimal | None:
    """Media de los registros en `[as_of − 6 días, as_of]`; `None` con menos de 3."""
    return _window_average(entries, as_of)


def exceeds_threshold(average: Decimal, reference: Decimal) -> bool:
    """`True` si la media difiere de la referencia en **más** de un 2%."""
    return abs(average - reference) / reference > THRESHOLD


def is_large_change(average: Decimal, reference: Decimal) -> bool:
    """`True` si la variación supera el 10% (aviso de posible registro erróneo)."""
    return abs(average - reference) / reference > LARGE_CHANGE


def moving_average_series(
    entries: Iterable[Entry], since: date | None
) -> list[tuple[date, Decimal, Decimal | None]]:
    """`(fecha, peso, media)` por cada día con registro desde `since`.

    `entries` incluye todos los registros: `since` solo filtra los días devueltos, no la ventana
    de la media. No interpola días sin registro.
    """
    ordered = sorted(entries, key=lambda e: e[0])
    return [
        (day, Decimal(kg), _window_average(ordered, day))
        for day, kg in ordered
        if since is None or day >= since
    ]
