"""Reglas puras de la copia de una comida (research R6, R7; data-model.md)."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import date, timedelta
from typing import Any

from mykcal.diary.schemas import MEALS
from mykcal.foods.nutrients import NUTRIENTS

WINDOW_DAYS = 14


def copy_window(target_date: date) -> tuple[date, date]:
    """Primer y último día que se pueden copiar: los 14 días naturales anteriores al destino."""
    return target_date - timedelta(days=WINDOW_DAYS), target_date - timedelta(days=1)


def source_in_window(source_date: date, target_date: date) -> bool:
    first, last = copy_window(target_date)
    return first <= source_date <= last


def order_meals(present: Iterable[str], target_meal: str) -> list[str]:
    """Las comidas con entradas: primero la del mismo tipo que el destino, luego el orden fijo."""
    have = set(present)
    ordered = [m for m in MEALS if m in have]
    if target_meal in have:
        ordered.remove(target_meal)
        ordered.insert(0, target_meal)
    return ordered


def copied_values(source: Any, food: Any | None) -> dict[str, Any]:
    """Campos de la entrada nueva que copia a `source`.

    Con el alimento disponible toma de él nombre, marca, unidad, ración y los 12 nutrientes por 100
    (FR-006); mantiene los g/ml de la origen y sus raciones solo si la ración no cambió. Sin
    alimento (borrado o archivado), conserva todo lo de la entrada origen.
    """
    if food is None:
        return {
            "food_name": source.food_name,
            "food_brand": source.food_brand,
            "base_unit": source.base_unit,
            "serving_size": source.serving_size,
            "quantity": source.quantity,
            "servings": source.servings,
            **{n: getattr(source, n) for n in NUTRIENTS},
        }
    same_serving = food.serving_size is not None and food.serving_size == source.serving_size
    return {
        "food_name": food.name,
        "food_brand": food.brand,
        "base_unit": food.base_unit,
        "serving_size": food.serving_size,
        "quantity": source.quantity,
        "servings": source.servings if same_serving else None,
        **{n: getattr(food, n) for n in NUTRIENTS},
    }
