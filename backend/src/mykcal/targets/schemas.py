from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

Sex = Literal["male", "female"]
ActivityLevel = Literal["sedentary", "light", "moderate", "high", "very_high"]
Goal = Literal["lose_fat", "maintain", "gain_muscle"]
Notice = Literal["MIN_KCAL_APPLIED", "CARBS_CLAMPED"]

Weight = Annotated[Decimal, Field(ge=30, le=300, max_digits=4, decimal_places=1)]


class TargetValues(BaseModel):
    """Los 12 valores del objetivo (contracts/api-changes.md); enteros ya redondeados."""

    model_config = ConfigDict(extra="forbid", from_attributes=True)

    kcal: int = Field(ge=1, le=10000)
    protein_g: int = Field(ge=0, le=1000)
    carbs_g: int = Field(ge=0, le=2000)
    fat_g: int = Field(ge=0, le=1000)
    fiber_g: int = Field(ge=0, le=200)
    sodium_mg: int = Field(ge=0, le=20000)
    potassium_mg: int = Field(ge=0, le=20000)
    calcium_mg: int = Field(ge=0, le=10000)
    iron_mg: int = Field(ge=0, le=200)
    magnesium_mg: int = Field(ge=0, le=5000)
    vitamin_d_ug: int = Field(ge=0, le=500)
    vitamin_c_mg: int = Field(ge=0, le=5000)


class Calculation(BaseModel):
    weight_kg: float
    age: int
    sex: Sex
    height_cm: int
    activity_level: ActivityLevel
    goal: Goal
    calculated_at: datetime
    notices: list[Notice]


class DailyTarget(BaseModel):
    values: TargetValues
    source: Literal["calculated", "manual"]
    effective_from: datetime
    calculation: Calculation
