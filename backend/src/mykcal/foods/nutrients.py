"""Nutrientes de un alimento: nombres, máximos por 100 y sumas con datos incompletos."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from decimal import Decimal

# Mismos nombres que TargetValues de la 002, para comparar alimentos con el objetivo (data-model).
NUTRIENTS: tuple[str, ...] = (
    "kcal",
    "protein_g",
    "carbs_g",
    "fat_g",
    "fiber_g",
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "magnesium_mg",
    "vitamin_d_ug",
    "vitamin_c_mg",
)
REQUIRED_NUTRIENTS: tuple[str, ...] = ("kcal", "protein_g", "carbs_g", "fat_g")
OPTIONAL_NUTRIENTS: tuple[str, ...] = tuple(n for n in NUTRIENTS if n not in REQUIRED_NUTRIENTS)

# Máximos por 100 g o 100 ml (data-model.md).
MAX_PER_100: dict[str, Decimal] = {
    "kcal": Decimal(900),
    "protein_g": Decimal(100),
    "carbs_g": Decimal(100),
    "fat_g": Decimal(100),
    "fiber_g": Decimal(100),
    "sodium_mg": Decimal(40000),
    "potassium_mg": Decimal(10000),
    "calcium_mg": Decimal(5000),
    "iron_mg": Decimal(500),
    "magnesium_mg": Decimal(2000),
    "vitamin_d_ug": Decimal(1000),
    "vitamin_c_mg": Decimal(5000),
}


@dataclass
class Totals:
    values: dict[str, Decimal] = field(default_factory=lambda: {n: Decimal(0) for n in NUTRIENTS})
    # Nutrientes en los que algún elemento no tenía dato: cuentan como 0 (FR-016).
    incomplete: set[str] = field(default_factory=set)


def sum_nutrients(items: Iterable[tuple[Mapping[str, Decimal | None], Decimal]]) -> Totals:
    """Suma (valores por 100, cantidad en g/ml). `None` cuenta como 0 y marca incompleto."""
    totals = Totals()
    for per100, quantity in items:
        factor = quantity / Decimal(100)
        for name in NUTRIENTS:
            value = per100.get(name)
            if value is None:
                totals.incomplete.add(name)
                continue
            totals.values[name] += value * factor
    return totals
