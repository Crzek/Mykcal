"""Cálculo del objetivo diario: función pura y determinista (research R1–R3).

Sin E/S, sin reloj y sin `float`. Los valores intermedios no se redondean; solo se redondea al
final cada valor de salida, con ROUND_HALF_UP.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

ACTIVITY_FACTOR = {
    "sedentary": Decimal("1.2"),
    "light": Decimal("1.375"),
    "moderate": Decimal("1.55"),
    "high": Decimal("1.725"),
    "very_high": Decimal("1.9"),
}
# objetivo: (factor de kcal, proteína en g/kg)
GOAL_RULES = {
    "lose_fat": (Decimal("0.80"), Decimal("2.2")),
    "maintain": (Decimal("1.00"), Decimal("1.8")),
    "gain_muscle": (Decimal("1.10"), Decimal("2.0")),
}
MIN_KCAL = {"male": Decimal(1500), "female": Decimal(1200)}
FAT_KCAL_SHARE = Decimal("0.25")

# Fibra y micros de FR-011. El hierro de la mujer depende de la edad (ver `_iron_mg`).
FIBER_G = {"male": 30, "female": 25}
SODIUM_MG = 2000
POTASSIUM_MG = 3500
CALCIUM_MG = 1000
MAGNESIUM_MG = {"male": 400, "female": 310}
VITAMIN_D_UG = 15
VITAMIN_C_MG = {"male": 90, "female": 75}

MIN_KCAL_APPLIED = "MIN_KCAL_APPLIED"
CARBS_CLAMPED = "CARBS_CLAMPED"


@dataclass(frozen=True)
class CalcInputs:
    sex: str
    age: int
    height_cm: int
    weight_kg: Decimal
    activity_level: str
    goal: str


@dataclass(frozen=True)
class CalcResult:
    bmr: Decimal
    tdee: Decimal
    kcal: int
    protein_g: int
    carbs_g: int
    fat_g: int
    fiber_g: int
    sodium_mg: int
    potassium_mg: int
    calcium_mg: int
    iron_mg: int
    magnesium_mg: int
    vitamin_d_ug: int
    vitamin_c_mg: int
    notices: list[str]

    @property
    def tdee_rounded(self) -> int:
        return _round(self.tdee)


def _round(value: Decimal) -> int:
    return int(value.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def _iron_mg(sex: str, age: int) -> int:
    if sex == "male" or age >= 51:
        return 8
    return 18


def calculate(inputs: CalcInputs) -> CalcResult:
    weight = Decimal(inputs.weight_kg)
    sex_term = Decimal(5) if inputs.sex == "male" else Decimal(-161)
    bmr = (
        Decimal(10) * weight
        + Decimal("6.25") * Decimal(inputs.height_cm)
        - Decimal(5) * Decimal(inputs.age)
        + sex_term
    )
    tdee = bmr * ACTIVITY_FACTOR[inputs.activity_level]
    kcal_factor, protein_per_kg = GOAL_RULES[inputs.goal]
    kcal = tdee * kcal_factor
    notices: list[str] = []
    if kcal < MIN_KCAL[inputs.sex]:
        kcal = MIN_KCAL[inputs.sex]
        notices.append(MIN_KCAL_APPLIED)

    protein = protein_per_kg * weight
    fat = kcal * FAT_KCAL_SHARE / Decimal(9)
    carbs = (kcal - Decimal(4) * protein - Decimal(9) * fat) / Decimal(4)
    if carbs < 0:
        carbs = Decimal(0)
        notices.append(CARBS_CLAMPED)

    return CalcResult(
        bmr=bmr,
        tdee=tdee,
        kcal=_round(kcal),
        protein_g=_round(protein),
        carbs_g=_round(carbs),
        fat_g=_round(fat),
        fiber_g=FIBER_G[inputs.sex],
        sodium_mg=SODIUM_MG,
        potassium_mg=POTASSIUM_MG,
        calcium_mg=CALCIUM_MG,
        iron_mg=_iron_mg(inputs.sex, inputs.age),
        magnesium_mg=MAGNESIUM_MG[inputs.sex],
        vitamin_d_ug=VITAMIN_D_UG,
        vitamin_c_mg=VITAMIN_C_MG[inputs.sex],
        notices=notices,
    )
