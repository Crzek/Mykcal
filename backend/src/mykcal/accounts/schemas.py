from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Me(BaseModel):
    id: uuid.UUID
    display_name: str
    is_admin: bool
    status: Literal["active", "disabled"]
    onboarding: Literal["consent", "profile", "done"]
    registered_at: datetime


class RegistrationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    invitation_code: str = Field(max_length=32)
