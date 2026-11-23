from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.core.auth import Principal, require_admin
from mykcal.db import get_session
from mykcal.invitations import service

router = APIRouter()


class InvitationStatusOut(BaseModel):
    code: str | None
    created_at: datetime | None
    active_accounts: int
    max_accounts: int
    free_seats: int


@router.get("/v1/admin/invitation", response_model=InvitationStatusOut)
async def get_invitation(
    _: Principal = Depends(require_admin), session: AsyncSession = Depends(get_session)
) -> InvitationStatusOut:
    return InvitationStatusOut(**(await service.get_status(session)).__dict__)


@router.post("/v1/admin/invitation/rotate", response_model=InvitationStatusOut)
async def rotate_invitation(
    principal: Principal = Depends(require_admin), session: AsyncSession = Depends(get_session)
) -> InvitationStatusOut:
    assert principal.account is not None
    status = await service.rotate(session, principal.account.id)
    return InvitationStatusOut(**status.__dict__)
