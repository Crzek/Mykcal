"""T016 (004): valores, totales, redondeo y restante del día (summary-cases.md, S1–S10, M1–M3)."""

import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

import pytest

from mykcal.diary.models import DiaryEntry
from mykcal.diary.summary import build_day
from mykcal.foods.nutrients import NUTRIENTS
from mykcal.targets.schemas import TargetValues

TARGET = TargetValues(
    kcal=2000,
    protein_g=150,
    carbs_g=200,
    fat_g=56,
    fiber_g=25,
    sodium_mg=2300,
    potassium_mg=3500,
    calcium_mg=1000,
    iron_mg=8,
    magnesium_mg=400,
    vitamin_d_ug=15,
    vitamin_c_mg=90,
)
DAY = date(2026, 11, 24)
MEAL_ORDER = ["breakfast", "lunch", "afternoon_snack", "dinner", "snacks"]


def entry(meal="breakfast", quantity=100, servings=None, **per_100) -> DiaryEntry:
    values = {"kcal": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0, **per_100}
    return DiaryEntry(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        entry_date=DAY,
        meal=meal,
        food_id=uuid.uuid4(),
        food_kind="generic",
        food_name="Alimento",
        food_brand=None,
        base_unit="g",
        serving_size=Decimal(30) if servings is not None else None,
        quantity=Decimal(str(quantity)),
        servings=None if servings is None else Decimal(str(servings)),
        created_at=datetime(2026, 11, 24, 8, 0, tzinfo=UTC),
        updated_at=datetime(2026, 11, 24, 8, 0, tzinfo=UTC),
        deleted_at=None,
        **{n: values.get(n) for n in NUTRIENTS},
    )


def day_of(*entries):
    return build_day(DAY, TARGET, list(entries))


def assert_balanced(day):
    """SC-002: consumido + restante = objetivo para cada valor."""
    for name in NUTRIENTS:
        consumed = Decimal(str(getattr(day.totals.consumed, name)))
        remaining = Decimal(str(day.remaining[name]))
        assert consumed + remaining == Decimal(getattr(TARGET, name)), name


def test_s1_dia_vacio():
    day = day_of()
    assert day.totals.consumed.kcal == 0
    assert day.remaining["kcal"] == 2000
    assert day.remaining["protein_g"] == 150
    assert day.totals.incomplete == []
    assert [m.meal for m in day.meals] == MEAL_ORDER
    assert all(m.entries == [] and m.totals.consumed.kcal == 0 for m in day.meals)
    assert_balanced(day)


def test_s2_valores_por_100_por_cantidad():
    day = day_of(entry(quantity=150, kcal=200))
    assert day.totals.consumed.kcal == 300
    assert day.remaining["kcal"] == 1700
    assert day.meals[0].entries[0].values.kcal == 300
    assert_balanced(day)


def test_s3_raciones_se_calculan_sobre_los_gramos():
    day = day_of(entry(quantity=60, servings=2, kcal=389, protein_g=Decimal("13.2")))
    assert day.totals.consumed.kcal == 233  # 233,4
    assert day.totals.consumed.protein_g == 7.9  # 7,92
    assert day.remaining["kcal"] == 1767
    e = day.meals[0].entries[0]
    assert e.quantity == 60 and e.servings == 2 and e.serving_size == 30
    assert_balanced(day)


def test_s4_se_redondea_el_total_no_cada_entrada():
    day = day_of(*[entry(kcal=Decimal("33.3")) for _ in range(3)])
    assert day.totals.consumed.kcal == 100  # 99,9
    assert [e.values.kcal for e in day.meals[0].entries] == [33, 33, 33]
    assert day.remaining["kcal"] == 1900
    assert_balanced(day)


def test_s5_exceso_es_un_restante_negativo():
    day = day_of(entry(quantity=100, kcal=2150))
    assert day.totals.consumed.kcal == 2150
    assert day.remaining["kcal"] == -150
    assert_balanced(day)


def test_s6_dato_faltante_marca_incompleto_y_cuenta_como_cero():
    day = day_of(entry(fiber_g=3), entry(meal="lunch"))
    assert day.totals.consumed.fiber_g == 3.0
    assert day.remaining["fiber_g"] == 22.0
    assert "fiber_g" in day.totals.incomplete
    assert "fiber_g" in day.meals[1].totals.incomplete  # la comida con la entrada sin dato
    assert "fiber_g" not in day.meals[0].totals.incomplete
    assert day.meals[1].entries[0].incomplete.count("fiber_g") == 1
    assert day.meals[0].entries[0].values.fiber_g == 3.0
    assert day.meals[1].entries[0].values.fiber_g is None
    assert_balanced(day)


def test_s6b_un_cero_explicito_no_es_incompleto():
    day = day_of(entry(fiber_g=0))
    assert "fiber_g" not in day.totals.incomplete


def test_s7_el_sodio_se_pasa_del_limite():
    day = day_of(entry(quantity=250, sodium_mg=1000))
    assert day.totals.consumed.sodium_mg == 2500
    assert day.remaining["sodium_mg"] == -200
    assert_balanced(day)


def test_s8_redondeo_half_up_a_un_decimal():
    day = day_of(entry(protein_g=Decimal("12.25")), entry(protein_g=Decimal("0.05")))
    assert day.totals.consumed.protein_g == 12.3
    assert day.remaining["protein_g"] == 137.7
    assert_balanced(day)


def test_s9_mismo_alimento_dos_veces_son_dos_entradas():
    day = day_of(entry(quantity=100, kcal=200), entry(quantity=50, kcal=200))
    assert len(day.meals[0].entries) == 2
    assert day.meals[0].totals.consumed.kcal == 300
    assert day.totals.consumed.kcal == 300


def test_s10_una_entrada_borrada_no_se_suma_ni_se_devuelve():
    borrada = entry(kcal=500)
    borrada.deleted_at = datetime(2026, 11, 24, 9, 0, tzinfo=UTC)
    day = day_of(borrada)
    assert day.totals.consumed.kcal == 0
    assert all(m.entries == [] for m in day.meals)


def test_m1_totales_por_comida_y_del_dia():
    day = day_of(entry("lunch", kcal=100), entry("dinner", kcal=200))
    by_meal = {m.meal: m.totals.consumed.kcal for m in day.meals}
    assert by_meal == {
        "breakfast": 0,
        "lunch": 100,
        "afternoon_snack": 0,
        "dinner": 200,
        "snacks": 0,
    }
    assert day.totals.consumed.kcal == 300


def test_m2_mover_una_entrada_cambia_los_totales_por_comida_no_el_del_dia():
    e = entry("lunch", kcal=300)
    antes = day_of(e)
    e.meal = "dinner"
    despues = day_of(e)
    assert antes.meals[1].totals.consumed.kcal == 300 and antes.meals[3].totals.consumed.kcal == 0
    assert (
        despues.meals[1].totals.consumed.kcal == 0 and despues.meals[3].totals.consumed.kcal == 300
    )
    assert antes.totals.consumed.kcal == despues.totals.consumed.kcal == 300


def test_m3_las_cinco_comidas_siempre_en_orden_fijo():
    day = day_of(entry("snacks", kcal=10), entry("breakfast", kcal=10))
    assert [m.meal for m in day.meals] == MEAL_ORDER


def test_entradas_de_una_comida_en_orden_de_creacion():
    a, b = entry(kcal=1), entry(kcal=2)
    a.created_at = datetime(2026, 11, 24, 9, 0, tzinfo=UTC)
    b.created_at = datetime(2026, 11, 24, 8, 0, tzinfo=UTC)
    day = day_of(a, b)
    assert [e.id for e in day.meals[0].entries] == [b.id, a.id]


@pytest.mark.parametrize("name", ["kcal", "sodium_mg", "iron_mg"])
def test_micros_y_kcal_a_entero_macros_a_un_decimal(name):
    day = day_of(entry(quantity=33, **{name: Decimal("10.5")}))  # 3,465
    value = getattr(day.totals.consumed, name)
    assert value == 3  # 3,465 → 3 a entero
    day = day_of(entry(quantity=100, protein_g=Decimal("3.46")))
    assert day.totals.consumed.protein_g == 3.5
