"""Esquemas de la API de IA (contracts/api-changes.md)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from mykcal.foods.schemas import FoodSummary


class AiKeyStatus(BaseModel):
    has_key: Literal[True] = True
    provider: Literal["gemini"]
    configured_at: datetime


class AiKeyCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    raw_key: str = Field(min_length=1, max_length=256)


class ProposedItem(BaseModel):
    ai_name: str
    ai_grams: float
    flagged: bool
    matched_food: FoodSummary | None = None
    matched_similarity: float | None = None
    kcal: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None


class PhotoAnalysisResult(BaseModel):
    items: list[ProposedItem]
