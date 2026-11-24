"""Resumen de un día: valores de las entradas, totales, redondeo y restante.

Funciones puras con `Decimal`, sin base de datos (principio VI, research R10).
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from datetime import date
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from mykcal.diary.models import DiaryEntry
from mykcal.diary.schemas import MEALS, DiaryDay, DiaryMeal, NutrientTotals
from mykcal.diary.schemas import DiaryEntry as DiaryEntryOut
from mykcal.foods.nutrients import NUTRIENTS, Totals, sum_nutrients
from mykcal.foods.schemas import Nutrients
from mykcal.targets.schemas import TargetValues

# Proteína, carbohidratos, grasa y fibra se muestran con 1 decimal; el resto, a entero.
ONE_DECIMAL = frozenset({"protein_g", "carbs_g", "fat_g", "fiber_g"})
_ZERO = Decimal(0)


def round_nutrient(name: str, value: Decimal) -> Decimal:
    exp = Decimal("0.1") if name in ONE_DECIMAL else Decimal(1)
    return value.quantize(exp, rounding=ROUND_HALF_UP)


def per_100(entry: DiaryEntry) -> dict[str, Decimal | None]:
    """Copia por 100 g/ml del alimento guardada en la entrada; `None` = sin dato."""
    return {name: getattr(entry, name) for name in NUTRIENTS}


def entry_values(entry: DiaryEntry) -> dict[str, Decimal | None]:
    """Valores de la entrada (por 100 × cantidad / 100), sin redondear (FR-003)."""
    factor = Decimal(entry.quantity) / Decimal(100)
    return {n: None if v is None else v * factor for n, v in per_100(entry).items()}


def _float(value: Decimal | None) -> float | None:
    return None if value is None else float(value)


def _nutrients(values: Mapping[str, Decimal | None]) -> Nutrients:
    return Nutrients(**{n: _float(values[n]) for n in NUTRIENTS})


def _totals(entries: Iterable[DiaryEntry]) -> NutrientTotals:
    totals: Totals = sum_nutrients((per_100(e), Decimal(e.quantity)) for e in entries)
    rounded = {n: round_nutrient(n, totals.values[n]) for n in NUTRIENTS}
    return NutrientTotals(
        consumed=_nutrients(rounded),
        incomplete=[n for n in NUTRIENTS if n in totals.incomplete],
    )


def _entry_out(entry: DiaryEntry) -> DiaryEntryOut:
    values = entry_values(entry)
    return DiaryEntryOut(
        id=entry.id,
        meal=entry.meal,  # type: ignore[arg-type]
        food_id=entry.food_id,
        food_kind=entry.food_kind,  # type: ignore[arg-type]
        food_name=entry.food_name,
        food_brand=entry.food_brand,
        base_unit=entry.base_unit,  # type: ignore[arg-type]
        serving_size=_float(entry.serving_size),
        per_100=_nutrients(per_100(entry)),
        quantity=float(entry.quantity),
        servings=_float(entry.servings),
        values=_nutrients(
            {n: None if v is None else round_nutrient(n, v) for n, v in values.items()}
        ),
        incomplete=[n for n in NUTRIENTS if values[n] is None],
        created_at=entry.created_at,
    )


def build_day(day: date, target: Any, entries: Iterable[DiaryEntry]) -> DiaryDay:
    """Arma el día: ignora las borradas, ordena por creación y deja las 5 comidas en orden fijo.

    `target` tiene los 12 valores del objetivo (`TargetValues` o una fila de `daily_target`).
    `restante = objetivo − consumido redondeado`: negativo es exceso, y así
    consumido + restante = objetivo siempre (SC-002).
    """
    active = sorted((e for e in entries if e.deleted_at is None), key=lambda e: e.created_at)
    target_values = TargetValues(**{n: getattr(target, n) for n in NUTRIENTS})
    totals = _totals(active)
    consumed = totals.consumed.model_dump()
    remaining = {
        n: float(Decimal(getattr(target_values, n)) - Decimal(str(consumed[n]))) for n in NUTRIENTS
    }
    meals = []
    for meal in MEALS:
        in_meal = [e for e in active if e.meal == meal]
        meals.append(
            DiaryMeal(
                meal=meal,  # type: ignore[arg-type]
                entries=[_entry_out(e) for e in in_meal],
                totals=_totals(in_meal),
            )
        )
    return DiaryDay(date=day, target=target_values, totals=totals, remaining=remaining, meals=meals)
