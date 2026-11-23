from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from mykcal.targets.schemas import ActivityLevel, DailyTarget, Goal, Sex, TargetValues, Weight


class ProfileInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    age: int = Field(ge=18, le=100)
    sex: Sex
    height_cm: int = Field(ge=100, le=250)
    weight_kg: Weight
    activity_level: ActivityLevel
    goal: Goal
    measured_on: date


class Profile(BaseModel):
    age: int
    sex: Sex
    height_cm: int
    weight_kg: float
    weight_measured_on: date
    activity_level: ActivityLevel
    goal: Goal
    updated_at: datetime


class Recalculation(BaseModel):
    status: Literal["created", "applied", "proposed", "none"]
    previous: TargetValues | None = None
    proposed: TargetValues | None = None


class ProfileSaved(BaseModel):
    profile: Profile
    target: DailyTarget
    recalculation: Recalculation
