"""T049 (005): reglas puras de la copia (contracts/quick-cases.md C1–C4 y V1–V5)."""

from datetime import date
from decimal import Decimal as D
from types import SimpleNamespace as NS

import pytest

from mykcal.diary.copy_rules import copied_values, copy_window, order_meals, source_in_window

TARGET = date(2026, 11, 24)


def test_ventana_de_14_dias_naturales_anteriores():
    assert copy_window(TARGET) == (date(2026, 11, 10), date(2026, 11, 23))
    assert source_in_window(date(2026, 11, 23), TARGET)
    assert source_in_window(date(2026, 11, 10), TARGET)
    assert not source_in_window(TARGET, TARGET)
    assert not source_in_window(date(2026, 11, 9), TARGET)
    assert not source_in_window(date(2026, 11, 25), TARGET)


@pytest.mark.parametrize(
    ("present", "expected"),
    [
        (["breakfast", "lunch", "dinner"], ["dinner", "breakfast", "lunch"]),  # C1
        (["breakfast", "snacks"], ["breakfast", "snacks"]),  # C2
        (["dinner"], ["dinner"]),  # C3
        ([], []),  # C4
    ],
)
def test_orden_de_comidas_con_la_del_destino_primero(present, expected):
    assert order_meals(present, "dinner") == expected


def test_el_orden_fijo_se_respeta_si_no_hay_del_mismo_tipo():
    assert order_meals(["snacks", "lunch", "afternoon_snack"], "breakfast") == [
        "lunch",
        "afternoon_snack",
        "snacks",
    ]


NUT = dict(
    kcal=D(300),
    protein_g=D(5),
    carbs_g=D(50),
    fat_g=D(10),
    fiber_g=None,
    sodium_mg=None,
    potassium_mg=None,
    calcium_mg=None,
    iron_mg=None,
    magnesium_mg=None,
    vitamin_d_ug=None,
    vitamin_c_mg=None,
)


def source():
    return NS(
        food_name="Mi bizcocho",
        food_brand=None,
        base_unit="g",
        serving_size=D(50),
        quantity=D(100),
        servings=D(2),
        **NUT,
    )


def food(**over):
    base = dict(name="Mi bizcocho", brand=None, base_unit="g", serving_size=D(50), **NUT)
    return NS(**{**base, **over})


def test_v1_sin_cambios():
    v = copied_values(source(), food())
    assert (v["kcal"], v["quantity"], v["servings"], v["food_name"]) == (300, 100, 2, "Mi bizcocho")


def test_v2_editado_toma_los_valores_actuales_y_mantiene_los_gramos():
    v = copied_values(source(), food(kcal=D(350), name="Bizcocho casero"))
    assert (v["kcal"], v["quantity"], v["servings"], v["food_name"]) == (
        350,
        100,
        2,
        "Bizcocho casero",
    )


def test_v3_racion_distinta_pierde_las_raciones():
    v = copied_values(source(), food(serving_size=D(80)))
    assert (v["kcal"], v["quantity"], v["servings"], v["serving_size"]) == (300, 100, None, 80)


def test_v3_racion_eliminada():
    v = copied_values(source(), food(serving_size=None))
    assert (v["quantity"], v["servings"], v["serving_size"]) == (100, None, None)


@pytest.mark.parametrize("case", ["V4 borrado", "V5 genérico archivado"])
def test_v4_v5_alimento_no_disponible_conserva_la_entrada(case):
    v = copied_values(source(), None)
    assert (v["kcal"], v["quantity"], v["servings"], v["food_name"], v["serving_size"]) == (
        300,
        100,
        2,
        "Mi bizcocho",
        50,
    )


def test_la_entrada_origen_no_se_modifica():
    src = source()
    copied_values(src, food(kcal=D(999), serving_size=D(80)))
    assert (src.kcal, src.servings, src.serving_size) == (300, 2, 50)
