"""SC-002: casos de referencia del cálculo (contracts/calc-cases.md de la spec 002)."""

from decimal import Decimal
from itertools import product

import pytest

from mykcal.targets.calc import CalcInputs, calculate

H, M = "male", "female"

# sexo, edad, altura, peso, actividad, objetivo | gasto, kcal, prot, grasa, carbs, hierro, avisos
CASES = [
    (H, 30, 180, "80", "moderate", "maintain", 2759, 2759, 144, 77, 373, 8, []),
    (H, 30, 180, "80", "moderate", "lose_fat", 2759, 2207, 176, 61, 238, 8, []),
    (H, 30, 180, "80", "moderate", "gain_muscle", 2759, 3035, 160, 84, 409, 8, []),
    (M, 35, 165, "60", "sedentary", "maintain", 1554, 1554, 108, 43, 183, 18, []),
    (H, 25, 175, "70", "light", "gain_muscle", 2301, 2532, 140, 70, 335, 8, []),
    (M, 40, 170, "65", "high", "lose_fat", 2331, 1865, 143, 52, 207, 18, []),
    (H, 28, 190, "95", "very_high", "maintain", 3805, 3805, 171, 106, 542, 8, []),
    (M, 30, 165, "60", "very_high", "gain_muscle", 2508, 2759, 120, 77, 397, 18, []),
    (M, 55, 160, "50", "sedentary", "lose_fat", 1277, 1200, 110, 33, 115, 8, ["MIN_KCAL_APPLIED"]),
    (H, 70, 160, "50", "sedentary", "lose_fat", 1386, 1500, 110, 42, 171, 8, ["MIN_KCAL_APPLIED"]),
    (M, 50, 165, "60", "light", "maintain", 1678, 1678, 108, 47, 207, 18, []),
    (M, 51, 165, "60", "light", "maintain", 1671, 1671, 108, 46, 205, 8, []),
    (M, 100, 100, "300", "sedentary", "lose_fat", 3557, 2845, 660, 79, 0, 8, ["CARBS_CLAMPED"]),
]


@pytest.mark.parametrize(
    "sex,age,height,weight,activity,goal,tdee,kcal,protein,fat,carbs,iron,notices", CASES
)
def test_casos_de_referencia(
    sex, age, height, weight, activity, goal, tdee, kcal, protein, fat, carbs, iron, notices
):
    r = calculate(CalcInputs(sex, age, height, Decimal(weight), activity, goal))
    assert r.tdee_rounded == tdee
    assert (r.kcal, r.protein_g, r.fat_g, r.carbs_g, r.iron_mg) == (
        kcal,
        protein,
        fat,
        carbs,
        iron,
    )
    assert r.notices == notices


def test_fibra_y_micros_por_sexo():
    hombre = calculate(CalcInputs(H, 30, 180, Decimal("80"), "moderate", "maintain"))
    mujer = calculate(CalcInputs(M, 30, 165, Decimal("60"), "moderate", "maintain"))
    assert (hombre.fiber_g, hombre.sodium_mg, hombre.potassium_mg, hombre.calcium_mg) == (
        30,
        2000,
        3500,
        1000,
    )
    assert (hombre.magnesium_mg, hombre.vitamin_d_ug, hombre.vitamin_c_mg) == (400, 15, 90)
    assert (mujer.fiber_g, mujer.sodium_mg, mujer.potassium_mg, mujer.calcium_mg) == (
        25,
        2000,
        3500,
        1000,
    )
    assert (mujer.magnesium_mg, mujer.vitamin_d_ug, mujer.vitamin_c_mg) == (310, 15, 75)


def test_rejilla_de_propiedades():
    ages = (18, 50, 51, 100)
    heights = (100, 250)
    weights = (Decimal("30"), Decimal("300"))
    activities = ("sedentary", "light", "moderate", "high", "very_high")
    goals = ("lose_fat", "maintain", "gain_muscle")
    for sex, age, h, w, a, g in product((H, M), ages, heights, weights, activities, goals):
        inputs = CalcInputs(sex, age, h, w, a, g)
        first, second = calculate(inputs), calculate(inputs)
        assert first == second  # determinista (FR-012)
        assert first.kcal >= (1500 if sex == H else 1200)
        assert first.carbs_g >= 0
        values = (
            first.kcal,
            first.protein_g,
            first.carbs_g,
            first.fat_g,
            first.fiber_g,
            first.sodium_mg,
            first.potassium_mg,
            first.calcium_mg,
            first.iron_mg,
            first.magnesium_mg,
            first.vitamin_d_ug,
            first.vitamin_c_mg,
        )
        assert all(isinstance(v, int) and v >= 0 for v in values)


def test_peso_con_decimal_no_usa_float():
    r = calculate(CalcInputs(H, 30, 180, Decimal("80.3"), "moderate", "maintain"))
    assert isinstance(r.kcal, int)
