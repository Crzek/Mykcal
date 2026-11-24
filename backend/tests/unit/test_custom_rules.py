"""R10, FR-013, FR-014: reglas puras de los alimentos personalizados."""

from decimal import Decimal

from mykcal.foods.custom_rules import kcal_mismatch, to_per_100, validate
from mykcal.foods.schemas import CustomFoodInput, CustomValues


def make(*, basis="per_100", serving=None, name="Tarta", brand=None, barcode=None, **values):
    base = {"kcal": 100, "protein_g": 5, "carbs_g": 10, "fat_g": 2}
    fields = {f: None for f in CustomValues.model_fields}
    fields.update({k: Decimal(str(v)) for k, v in {**base, **values}.items()})
    return CustomFoodInput.model_construct(
        name=name,
        brand=brand,
        barcode=barcode,
        base_unit="g",
        basis=basis,
        serving_size=None if serving is None else Decimal(serving),
        values=CustomValues.model_construct(**fields),
    )


def test_por_racion_se_convierte_a_100():
    out = to_per_100(make(basis="per_serving", serving=150, kcal=480))
    assert out["kcal"] == Decimal("320")


def test_redondeo_half_up_a_dos_decimales():
    out = to_per_100(make(basis="per_serving", serving=3, kcal=1, protein_g="0.015"))
    assert out["kcal"] == Decimal("33.33")  # 100/3
    assert out["protein_g"] == Decimal("0.50")
    half = to_per_100(make(protein_g="1.005"))
    assert half["protein_g"] == Decimal("1.01")


def test_por_100_no_cambia_los_valores():
    assert to_per_100(make(kcal=250))["kcal"] == Decimal("250")


def test_opcionales_ausentes_son_none():
    out = to_per_100(make())
    assert out["fiber_g"] is None
    assert out["vitamin_d_ug"] is None


def test_todo_correcto_no_da_errores():
    assert validate(make()) == []


def test_por_racion_sin_racion_falla_en_serving_size():
    assert validate(make(basis="per_serving")) == ["serving_size"]
    assert validate(make(basis="per_serving", serving=0)) == ["serving_size"]


def test_valor_negativo():
    assert validate(make(fat_g=-1)) == ["fat_g"]
    assert validate(make(sodium_mg=-5)) == ["sodium_mg"]


def test_suma_de_macros_y_fibra_mayor_que_100():
    assert validate(make(protein_g=50, carbs_g=40, fat_g=20)) == [
        "protein_g",
        "carbs_g",
        "fat_g",
        "fiber_g",
    ]
    assert validate(make(protein_g=0, carbs_g=60, fat_g=0, fiber_g=60)) == [
        "protein_g",
        "carbs_g",
        "fat_g",
        "fiber_g",
    ]
    assert validate(make(protein_g=40, carbs_g=40, fat_g=20)) == []  # 100 exactos


def test_la_suma_se_comprueba_tras_convertir():
    # 60 g de carbohidratos en una ración de 50 g son 120 por 100.
    assert "carbs_g" in validate(make(basis="per_serving", serving=50, carbs_g=60))


def test_maximo_por_100():
    assert validate(make(kcal=901)) == ["kcal"]
    assert validate(make(kcal=900, protein_g=0, carbs_g=0, fat_g=0)) == []
    assert validate(make(sodium_mg=40001)) == ["sodium_mg"]
    assert validate(make(vitamin_d_ug=1001)) == ["vitamin_d_ug"]


def test_nombre_vacio_espacios_y_largo():
    assert validate(make(name="")) == ["name"]
    assert validate(make(name="   ")) == ["name"]
    assert validate(make(name="a" * 120)) == []
    assert validate(make(name="a" * 121)) == ["name"]


def test_marca_de_81_caracteres():
    assert validate(make(brand="m" * 80)) == []
    assert validate(make(brand="m" * 81)) == ["brand"]


def test_codigo_no_valido():
    assert validate(make(barcode="8410000000016")) == []
    assert validate(make(barcode="8410000000017")) == ["barcode"]


def test_kcal_mismatch_en_el_limite():
    # calculadas = 4·25 = 100; 115 es exactamente un 15 %: no avisa.
    base = {"protein_g": 25, "carbs_g": 0, "fat_g": 0}
    assert not kcal_mismatch(to_per_100(make(kcal=115, **base)))
    assert kcal_mismatch(to_per_100(make(kcal=116, **base)))
    assert not kcal_mismatch(to_per_100(make(kcal=85, **base)))
    assert kcal_mismatch(to_per_100(make(kcal=84, **base)))


def test_kcal_mismatch_con_calculadas_cero():
    zero = {"protein_g": 0, "carbs_g": 0, "fat_g": 0}
    assert kcal_mismatch(to_per_100(make(kcal=10, **zero)))
    assert not kcal_mismatch(to_per_100(make(kcal=0, **zero)))
