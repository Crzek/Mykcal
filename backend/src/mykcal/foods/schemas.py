"""Esquemas de la API de alimentos (contracts/api-changes.md)."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

FoodKind = Literal["generic", "packaged", "custom"]
BaseUnit = Literal["g", "ml"]
Source = Literal["ciqual", "off", "user"]
Basis = Literal["per_100", "per_serving"]
BARCODE_PATTERN = r"^[0-9]{8}$|^[0-9]{12,14}$"


class Nutrients(BaseModel):
    """Valores por 100 g o 100 ml. `None` = sin dato (FR-003)."""

    model_config = ConfigDict(extra="forbid")

    kcal: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float | None
    sodium_mg: float | None
    potassium_mg: float | None
    calcium_mg: float | None
    iron_mg: float | None
    magnesium_mg: float | None
    vitamin_d_ug: float | None
    vitamin_c_mg: float | None


class FoodSummary(BaseModel):
    id: uuid.UUID
    kind: FoodKind
    name: str
    brand: str | None
    base_unit: BaseUnit
    kcal: float
    is_mine: bool


class FoodSearchResult(BaseModel):
    items: list[FoodSummary] = Field(max_length=20)


class Food(BaseModel):
    id: uuid.UUID
    kind: FoodKind
    name: str
    brand: str | None
    barcode: str | None
    base_unit: BaseUnit
    per_100: Nutrients
    serving_size: float | None
    is_mine: bool
    source: Source
    updated_at: datetime


class BarcodeLookup(BaseModel):
    result: Literal["found", "not_found", "incomplete"]
    code: str
    food: Food | None = None
    stale: bool | None = None
    product_name: str | None = None
    brand: str | None = None


class CustomValues(BaseModel):
    """Valores por 100 o por ración, según `basis`. Los opcionales ausentes = sin dato."""

    model_config = ConfigDict(extra="forbid")

    kcal: Decimal = Field(ge=0)
    protein_g: Decimal = Field(ge=0)
    carbs_g: Decimal = Field(ge=0)
    fat_g: Decimal = Field(ge=0)
    fiber_g: Decimal | None = Field(default=None, ge=0)
    sodium_mg: Decimal | None = Field(default=None, ge=0)
    potassium_mg: Decimal | None = Field(default=None, ge=0)
    calcium_mg: Decimal | None = Field(default=None, ge=0)
    iron_mg: Decimal | None = Field(default=None, ge=0)
    magnesium_mg: Decimal | None = Field(default=None, ge=0)
    vitamin_d_ug: Decimal | None = Field(default=None, ge=0)
    vitamin_c_mg: Decimal | None = Field(default=None, ge=0)


class CustomFoodInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=120)
    brand: str | None = Field(default=None, max_length=80)
    barcode: str | None = Field(default=None, pattern=BARCODE_PATTERN)
    base_unit: BaseUnit
    basis: Basis
    serving_size: Decimal | None = Field(default=None, gt=0, le=5000)
    values: CustomValues


class CustomFoodSaved(BaseModel):
    food: Food
    warnings: list[Literal["KCAL_MISMATCH"]]


class CustomFoodList(BaseModel):
    items: list[FoodSummary]
