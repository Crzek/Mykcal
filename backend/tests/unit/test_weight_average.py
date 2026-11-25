"""T003 (007): media semanal, umbral y serie de la gráfica (contracts/average-cases.md)."""

from datetime import date, timedelta
from decimal import Decimal

import pytest

from mykcal.weight.average import (
    exceeds_threshold,
    is_large_change,
    moving_average_series,
    weekly_average,
)

AS_OF = date(2026, 11, 20)


def entries(*pairs: tuple[int, str]) -> list[tuple[date, Decimal]]:
    return [(AS_OF - timedelta(days=ago), Decimal(kg)) for ago, kg in pairs]


@pytest.mark.parametrize(
    ("registros", "esperada"),
    [
        (((0, "78.0"), (1, "78.5"), (2, "79.0")), "78.5"),
        (((0, "78.1"), (1, "78.2"), (2, "78.2")), "78.2"),  # 78.166… → 78.2
        (((0, "78.0"), (1, "78.1"), (2, "78.2"), (3, "78.3")), "78.2"),  # 78.15 → 78.2
        (((0, "76.0"), (3, "76.0"), (6, "76.0")), "76.0"),  # justo 3
        (((0, "77.0"), (1, "77.0")), None),  # menos de 3
        (((0, "78.0"), (1, "78.0"), (2, "78.0"), (8, "70.0")), "78.0"),  # 8 días fuera
        (((0, "76.0"),), None),  # solo hoy
    ],
)
def test_weekly_average(registros, esperada):
    result = weekly_average(entries(*registros), AS_OF)
    assert result == (Decimal(esperada) if esperada is not None else None)


@pytest.mark.parametrize(
    ("media", "referencia", "esperado"),
    [
        ("78.2", "80.0", True),
        ("78.6", "80.0", False),
        ("78.4", "80.0", False),  # exactamente 2%
        ("78.3", "80.0", True),
        ("81.7", "80.0", True),
        ("81.6", "80.0", False),
        ("71.0", "80.0", True),
    ],
)
def test_exceeds_threshold(media, referencia, esperado):
    assert exceeds_threshold(Decimal(media), Decimal(referencia)) is esperado


def test_is_large_change():
    assert is_large_change(Decimal("71.0"), Decimal("80.0")) is True
    assert is_large_change(Decimal("72.0"), Decimal("80.0")) is False  # exactamente 10%


def test_serie_ventana_con_tres_registros():
    series = moving_average_series(entries((0, "78.0"), (1, "78.5"), (2, "79.0")), None)
    by_day = {d: (w, m) for d, w, m in series}
    assert by_day[AS_OF] == (Decimal("78.0"), Decimal("78.5"))
    assert by_day[AS_OF - timedelta(days=1)][1] is None  # solo 2 en su ventana
    assert by_day[AS_OF - timedelta(days=2)][1] is None


def test_serie_ventana_con_dos_registros():
    series = moving_average_series(entries((0, "78.0"), (1, "78.5")), None)
    assert [m for _, _, m in series] == [None, None]


def test_serie_primer_registro():
    series = moving_average_series(entries((0, "78.0")), None)
    assert series == [(AS_OF, Decimal("78.0"), None)]


def test_serie_no_interpola_dias_sin_registro():
    series = moving_average_series(entries((0, "78.0"), (5, "79.0")), None)
    assert [d for d, _, _ in series] == [AS_OF - timedelta(days=5), AS_OF]


def test_serie_ventana_cruza_since():
    """El primer día del periodo usa registros anteriores a `since` en su ventana."""
    since = AS_OF - timedelta(days=2)
    registros = entries((0, "78.0"), (1, "78.0"), (2, "78.0"), (3, "80.0"), (4, "80.0"))
    by_day = {d: m for d, _, m in moving_average_series(registros, since)}
    assert min(by_day) == since  # los días anteriores a `since` no se devuelven
    assert by_day[since] == Decimal("79.3")  # (78 + 80 + 80) / 3 = 79.33…
