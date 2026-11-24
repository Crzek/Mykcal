from decimal import Decimal

from mykcal.foods.nutrients import NUTRIENTS, REQUIRED_NUTRIENTS, sum_nutrients


def per100(**over):
    base = {n: None for n in NUTRIENTS}
    base.update(
        kcal=Decimal("100"), protein_g=Decimal("10"), carbs_g=Decimal("20"), fat_g=Decimal("5")
    )
    base.update({k: (Decimal(str(v)) if v is not None else None) for k, v in over.items()})
    return base


def test_nombres_y_obligatorios():
    assert NUTRIENTS[:4] == ("kcal", "protein_g", "carbs_g", "fat_g")
    assert len(NUTRIENTS) == 12
    assert REQUIRED_NUTRIENTS == ("kcal", "protein_g", "carbs_g", "fat_g")


def test_escala_por_cantidad_y_suma():
    totals = sum_nutrients([(per100(), Decimal("150")), (per100(), Decimal("50"))])
    assert totals.values["kcal"] == Decimal("200")
    assert totals.values["protein_g"] == Decimal("20")


def test_none_cuenta_como_cero_y_marca_incompleto():
    totals = sum_nutrients([(per100(fiber_g=2), Decimal("100")), (per100(), Decimal("100"))])
    assert totals.values["fiber_g"] == Decimal("2")
    assert totals.incomplete == {
        "fiber_g",
        "sodium_mg",
        "potassium_mg",
        "calcium_mg",
        "iron_mg",
        "magnesium_mg",
        "vitamin_d_ug",
        "vitamin_c_mg",
    }


def test_cero_explicito_no_es_incompleto():
    full = {n: Decimal("0") for n in NUTRIENTS}
    totals = sum_nutrients([(full, Decimal("100"))])
    assert totals.incomplete == set()
    assert totals.values["vitamin_d_ug"] == Decimal("0")


def test_sin_elementos():
    totals = sum_nutrients([])
    assert totals.values["kcal"] == Decimal("0")
    assert totals.incomplete == set()
