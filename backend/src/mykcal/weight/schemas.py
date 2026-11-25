from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

from mykcal.targets.schemas import TargetValues, Weight


class WeightInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    measured_on: date
    weight_kg: Weight


class WeightUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    weight_kg: Weight


class WeightEntry(BaseModel):
    measured_on: date
    weight_kg: float
    updated_at: datetime


class WeightList(BaseModel):
    entries: list[WeightEntry]


class WeightChartPoint(BaseModel):
    date: date
    weight_kg: float
    average_kg: float | None


class WeightChartSummary(BaseModel):
    count: int
    current_weight_kg: float | None
    weekly_average_kg: float | None
    change_kg: float | None


class WeightChart(BaseModel):
    period: Literal["p30", "p90", "all"]
    points: list[WeightChartPoint]
    summary: WeightChartSummary


class RecalcProposal(BaseModel):
    status: Literal["pending", "none"]
    reference_weight_kg: float | None = None
    weekly_average_kg: float | None = None
    was_manual: bool | None = None
    large_change: bool | None = None
    current: TargetValues | None = None
    proposed: TargetValues | None = None
