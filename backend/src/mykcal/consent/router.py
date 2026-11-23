from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.consent import service
from mykcal.core.auth import Principal, require_active_account
from mykcal.db import get_session

router = APIRouter()


class ConsentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    text_version: str = Field(min_length=1, max_length=32)


class Consent(BaseModel):
    text_version: str
    accepted_at: datetime


@router.post("/v1/consent", response_model=Consent, status_code=201)
async def post_consent(
    body: ConsentRequest,
    principal: Principal = Depends(require_active_account),
    session: AsyncSession = Depends(get_session),
) -> Consent:
    assert principal.account is not None
    row = await service.accept(session, principal.account.id, body.text_version)
    return Consent(text_version=row.text_version, accepted_at=row.accepted_at)
