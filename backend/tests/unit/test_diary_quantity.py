"""T035 (004): cantidad en g/ml o en raciones (Q1–Q7 de summary-cases.md, research R6)."""

from decimal import Decimal

import pytest

from mykcal.core.errors import ApiError, ErrorCode
from mykcal.diary.quantity import resolve_quantity

D = Decimal


def fails(quantity, servings, serving_size, fields):
    with pytest.raises(ApiError) as exc:
        resolve_quantity(quantity, servings, serving_size)
    assert exc.value.status == 400
    assert exc.value.code == ErrorCode.VALIDATION_ERROR
    assert exc.value.fields == fields


def test_q1_raciones_por_tamano_de_racion_a_un_decimal_half_up():
    assert resolve_quantity(None, D("1.5"), D("33.3")) == (D("50.0"), D("1.5"))  # 49,95
    assert resolve_quantity(None, D(2), D(30)) == (D("60.0"), D(2))
    assert resolve_quantity(None, D("0.25"), D(30)) == (D("7.5"), D("0.25"))


def test_cantidad_en_gramos_no_lleva_raciones():
    assert resolve_quantity(D("150"), None, None) == (D("150"), None)
    assert resolve_quantity(D("80.5"), None, D(30)) == (D("80.5"), None)


def test_q2_raciones_sin_tamano_de_racion():
    fails(None, D(2), None, ["servings"])


def test_q3_los_dos_campos_a_la_vez():
    fails(D(100), D(2), D(30), ["quantity", "servings"])


def test_q4_ninguno_de_los_dos():
    fails(None, None, D(30), ["quantity", "servings"])


@pytest.mark.parametrize("bad", [D(0), D(-5), D("-0.1")])
def test_q4_cantidad_cero_o_negativa(bad):
    fails(bad, None, None, ["quantity"])
    fails(None, bad, D(30), ["servings"])


def test_q5_mas_de_10000():
    fails(D("10000.1"), None, None, ["quantity"])
    assert resolve_quantity(D(10000), None, None) == (D(10000), None)


def test_raciones_cuyo_total_pasa_de_10000():
    fails(None, D(100), D(101), ["servings"])  # 10.100 g
    assert resolve_quantity(None, D(100), D(100)) == (D("10000.0"), D(100))


def test_raciones_tan_pequenas_que_la_cantidad_redondea_a_cero():
    fails(None, D("0.01"), D(1), ["servings"])  # 0,01 g → 0,0
