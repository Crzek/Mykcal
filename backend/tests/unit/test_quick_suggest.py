"""T014 (005): cantidad sugerida de recientes y favoritos (contracts/quick-cases.md A1–A9)."""

from decimal import Decimal as D

import pytest

from mykcal.quick.suggest import LastUse, suggest_amount

CASES = [
    # id, última (cantidad, raciones, ración de la entrada), ración del alimento hoy, esperado
    ("A1", (150, None, None), None, (150, None)),
    ("A2", (60, 2, 30), 30, (60, 2)),
    ("A3", (60, 2, 30), 40, (60, None)),
    ("A4", (60, 2, 30), None, (60, None)),
    ("A5", (45, None, None), 30, (45, None)),
    ("A6", None, 30, (30, 1)),
    ("A7", None, None, (100, None)),
    ("A8", None, None, (100, None)),
    ("A9", (125, "0.5", 250), 250, (125, "0.5")),
]


@pytest.mark.parametrize(("case", "last", "serving", "expected"), CASES, ids=[c[0] for c in CASES])
def test_cantidad_sugerida(case, last, serving, expected):
    use = (
        None
        if last is None
        else LastUse(
            D(str(last[0])),
            None if last[1] is None else D(str(last[1])),
            None if last[2] is None else D(str(last[2])),
        )
    )
    quantity, servings = suggest_amount(use, None if serving is None else D(str(serving)))
    assert quantity == D(str(expected[0]))
    assert servings == (None if expected[1] is None else D(str(expected[1])))


def test_la_cantidad_de_una_racion_se_redondea_a_un_decimal():
    """12,55 g por ración × 1 = 12,6 g (mitad hacia arriba), como resolve_quantity."""
    quantity, servings = suggest_amount(None, D("12.55"))
    assert quantity == D("12.6") and servings == 1
