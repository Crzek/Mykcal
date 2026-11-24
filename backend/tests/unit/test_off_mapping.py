"""R8: conversión de los nutrientes de Open Food Facts, sin red."""

import json
from decimal import Decimal
from pathlib import Path

from mykcal.foods.off_client import NO_NAME, map_product

FIXTURES = Path(__file__).parent.parent / "fixtures" / "off"


def load(name: str) -> dict:
    return json.loads((FIXTURES / f"{name}.json").read_text(encoding="utf-8"))


def payload(nutriments: dict, **product) -> dict:
    base = {"product_name": "X", "nutriments": nutriments}
    return {"code": "8410000000016", "status": 1, "product": {**base, **product}}


MACROS = {"energy-kcal_100g": 50, "proteins_100g": 1, "carbohydrates_100g": 10, "fat_100g": 1}


def test_gramos_a_miligramos_y_vitamina_d_a_microgramos():
    result = map_product(load("found_grams"))
    n = result.product.nutrients
    assert result.status == "found"
    assert n["sodium_mg"] == Decimal("46")
    assert n["calcium_mg"] == Decimal("120")
    assert n["vitamin_d_ug"] == Decimal("0.50")
    assert n["kcal"] == Decimal("61")
    assert n["fiber_g"] == Decimal("0")


def test_todos_los_micros_usan_su_factor():
    n = map_product(
        payload(
            {
                **MACROS,
                "sodium_100g": 0.001,
                "potassium_100g": 0.002,
                "calcium_100g": 0.003,
                "iron_100g": 0.004,
                "magnesium_100g": 0.005,
                "vitamin-c_100g": 0.006,
                "vitamin-d_100g": 0.000001,
            }
        )
    ).product.nutrients
    assert (n["sodium_mg"], n["potassium_mg"], n["calcium_mg"]) == (1, 2, 3)
    assert (n["iron_mg"], n["magnesium_mg"], n["vitamin_c_mg"]) == (4, 5, 6)
    assert n["vitamin_d_ug"] == 1


def test_kj_se_convierte_a_kcal():
    result = map_product(load("kj_only"))
    assert result.status == "found"
    assert result.product.nutrients["kcal"] == Decimal("439.77")  # 1840 / 4,184


def test_kcal_gana_a_kj_si_estan_los_dos():
    n = map_product(payload({**MACROS, "energy-kj_100g": 9999})).product.nutrients
    assert n["kcal"] == Decimal("50")


def test_campo_ausente_es_sin_dato():
    n = map_product(payload(MACROS)).product.nutrients
    assert n["fiber_g"] is None
    assert n["sodium_mg"] is None
    assert n["vitamin_d_ug"] is None


def test_redondeo_half_up_a_dos_decimales():
    n = map_product(payload({**MACROS, "proteins_100g": 1.005, "fat_100g": "2.675"})).product
    assert n.nutrients["protein_g"] == Decimal("1.01")
    assert n.nutrients["fat_g"] == Decimal("2.68")


def test_unidad_base_ml_para_ml_cl_y_l():
    for unit in ("ml", "cl", "l", "ML"):
        assert map_product(payload(MACROS, product_quantity_unit=unit)).product.base_unit == "ml"
    assert map_product(payload(MACROS, product_quantity_unit="g")).product.base_unit == "g"
    assert map_product(payload(MACROS)).product.base_unit == "g"
    assert map_product(load("found_ml")).product.base_unit == "ml"


def test_racion_solo_si_es_mayor_que_cero():
    assert map_product(load("found_grams")).product.serving_size == Decimal("125")
    assert map_product(payload(MACROS, serving_quantity=0)).product.serving_size is None
    assert map_product(payload(MACROS, serving_quantity="-3")).product.serving_size is None
    assert map_product(payload(MACROS, serving_quantity="abc")).product.serving_size is None
    assert map_product(payload(MACROS)).product.serving_size is None


def test_nombre_prefiere_espanol_y_cae_a_sin_nombre():
    assert map_product(load("found_grams")).product.name == "Yogur natural sin azúcar"
    assert map_product(payload(MACROS, product_name="Solo base")).product.name == "Solo base"
    assert map_product(load("no_name")).product.name == NO_NAME


def test_marca_es_la_primera():
    assert map_product(load("found_grams")).product.brand == "Marca Uno"


def test_incompleto_si_falta_un_macro_y_conserva_nombre_y_marca():
    for missing in ("energy-kcal_100g", "proteins_100g", "carbohydrates_100g", "fat_100g"):
        nutriments = {k: v for k, v in MACROS.items() if k != missing}
        result = map_product(payload(nutriments, brands="Marca"))
        assert result.status == "incomplete"
        assert result.product is None
        assert (result.name, result.brand) == ("X", "Marca")
    full = map_product(load("no_macros"))
    assert full.status == "incomplete"
    assert full.name == "Producto sin tabla"


def test_status_cero_es_not_found():
    assert map_product(load("not_found")).status == "not_found"


def test_valor_imposible_cuenta_como_ausente():
    assert map_product(payload({**MACROS, "energy-kcal_100g": 5000})).status == "incomplete"
    n = map_product(payload({**MACROS, "sodium_100g": 500})).product.nutrients
    assert n["sodium_mg"] is None
