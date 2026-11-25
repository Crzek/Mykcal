"""Rutas de la clave de IA y del análisis de fotos. Todas exigen consentimiento (FR-004)."""

from __future__ import annotations

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Form, Request, Response, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.formparsers import MultiPartParser

from mykcal import clock
from mykcal.ai import service
from mykcal.ai.schemas import AiKeyCreate, AiKeyStatus, PhotoAnalysisResult
from mykcal.core.auth import Principal, require_consent
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.db import get_session
from mykcal.diary.schemas import Meal

# Starlette vuelca a un fichero temporal las partes mayores de 1 MB: se sube el umbral al tope de
# la foto para que nunca toque el disco (FR-012).
MultiPartParser.spool_max_size = 5 * 1024 * 1024

router = APIRouter()

MAX_PHOTO_BYTES = 4 * 1024 * 1024


@router.get("/v1/ai-key", response_model=AiKeyStatus)
async def get_ai_key(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> AiKeyStatus:
    assert principal.account is not None
    return await service.get_key_status(session, principal.account.id)


@router.put("/v1/ai-key", response_model=AiKeyStatus)
async def put_ai_key(
    body: AiKeyCreate,
    request: Request,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> AiKeyStatus:
    assert principal.account is not None
    return await service.save_key(
        session,
        principal.account.id,
        body.raw_key,
        request.app.state.ai_provider,
        request.app.state.settings.ai_key_master.get_secret_value(),
        clock.utcnow(),
    )


@router.delete("/v1/ai-key", status_code=204)
async def delete_ai_key(
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> Response:
    assert principal.account is not None
    await service.delete_key(session, principal.account.id)
    return Response(status_code=204)


@router.post("/v1/photo-analysis", response_model=PhotoAnalysisResult)
async def photo_analysis(
    request: Request,
    photo: UploadFile,
    meal: Annotated[Meal, Form()],
    entry_date: Annotated[date, Form()],
    description: Annotated[str | None, Form(max_length=500)] = None,
    total_grams: Annotated[int | None, Form(ge=1)] = None,
    principal: Principal = Depends(require_consent),
    session: AsyncSession = Depends(get_session),
) -> PhotoAnalysisResult:
    assert principal.account is not None
    data = await photo.read(MAX_PHOTO_BYTES + 1)  # solo en memoria: nunca a disco (FR-012)
    if len(data) > MAX_PHOTO_BYTES:
        raise ApiError(413, ErrorCode.VALIDATION_ERROR, "La foto es demasiado grande (máx. 4 MB).")
    settings = request.app.state.settings
    return await service.analyze_photo(
        session,
        principal.account.id,
        request.app.state.ai_provider,
        settings.ai_key_master.get_secret_value(),
        settings.ai_model,
        data,
        description,
        total_grams,
    )
