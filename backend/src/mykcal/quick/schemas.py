"""Esquemas de recientes y favoritos (contracts/api-changes.md)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field

from mykcal.foods.schemas import Food

# Cantidades listas para enviarse a `POST /v1/diary/entries` (research R2).
SuggestedQuantity = Annotated[float, Field(gt=0, le=10000)]
SuggestedServings = Annotated[float, Field(gt=0, le=100)]


class QuickFood(BaseModel):
    food: Food
    suggested_quantity: SuggestedQuantity
    suggested_servings: SuggestedServings | None
    last_used_at: datetime | None
    is_favorite: bool


class QuickFoodList(BaseModel):
    items: list[QuickFood]
