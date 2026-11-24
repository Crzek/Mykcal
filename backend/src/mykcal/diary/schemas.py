"""Esquemas de la API del diario (contracts/api-changes.md)."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

from mykcal.foods.schemas import BaseUnit, FoodKind, Nutrients
from mykcal.targets.schemas import TargetValues

Meal = Literal["breakfast", "lunch", "afternoon_snack", "dinner", "snacks"]
MEALS: tuple[str, ...] = ("breakfast", "lunch", "afternoon_snack", "dinner", "snacks")

# Cantidad en g/ml (1 decimal) y raciones (2 decimales), research R6.
Quantity = Annotated[Decimal, Field(gt=0, le=10000, max_digits=6, decimal_places=1)]
Servings = Annotated[Decimal, Field(gt=0, le=100, max_digits=5, decimal_places=2)]


class DiaryEntryCreate(BaseModel):
    """Lleva `quantity` o `servings`, nunca los dos: lo comprueba `quantity.resolve_quantity`."""

    model_config = ConfigDict(extra="forbid")

    date: date
    meal: Meal
    food_id: uuid.UUID
    quantity: Quantity | None = None
    servings: Servings | None = None


class DiaryEntryUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    meal: Meal | None = None
    quantity: Quantity | None = None
    servings: Servings | None = None


class DiaryEntry(BaseModel):
    id: uuid.UUID
    meal: Meal
    food_id: uuid.UUID
    food_kind: FoodKind
    food_name: str
    food_brand: str | None
    base_unit: BaseUnit
    serving_size: float | None
    per_100: Nutrients
    quantity: float
    servings: float | None
    values: Nutrients
    incomplete: list[str]
    created_at: datetime


class NutrientTotals(BaseModel):
    consumed: Nutrients
    incomplete: list[str]


class DiaryMeal(BaseModel):
    meal: Meal
    entries: list[DiaryEntry]
    totals: NutrientTotals


class DiaryDay(BaseModel):
    date: date
    target: TargetValues
    totals: NutrientTotals
    remaining: dict[str, float]
    meals: list[DiaryMeal] = Field(min_length=5, max_length=5)


class DiaryCopyCreate(BaseModel):
    """Copia todas las entradas de una comida a una comida del día destino (research R5)."""

    model_config = ConfigDict(extra="forbid")

    source_date: date
    source_meal: Meal
    target_date: date
    target_meal: Meal


class DiaryCopyResult(BaseModel):
    copy_id: uuid.UUID
    entry_ids: list[uuid.UUID] = Field(min_length=1)
    day: DiaryDay


class CopySourceEntry(BaseModel):
    food_name: str
    food_brand: str | None
    base_unit: BaseUnit
    quantity: float
    servings: float | None
    kcal: float


class CopySourceMeal(BaseModel):
    meal: Meal
    entries: list[CopySourceEntry] = Field(min_length=1)
    kcal: float
    values_changed: bool


class CopySourceDay(BaseModel):
    date: date
    meals: list[CopySourceMeal] = Field(min_length=1, max_length=5)


class CopySourceList(BaseModel):
    days: list[CopySourceDay] = Field(max_length=14)
