"""Clave de IA y análisis de fotos. Nunca se registra la foto, la respuesta ni la clave (R10)."""

from __future__ import annotations

import time
import uuid
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.ai import crypto, repository
from mykcal.ai.matching import match_items
from mykcal.ai.prompt import AiResponseInvalid, AiUnrecognized, build_prompt, parse_response
from mykcal.ai.provider import (
    AiKeyInvalid,
    AiProvider,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
)
from mykcal.ai.schemas import AiKeyStatus, PhotoAnalysisResult
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.logging import get_logger

PROVIDER = "gemini"

# excepción de dominio → (resultado registrado, HTTP, código, mensaje) — research R11
_FAILURES: list[tuple[type[Exception], str, int, ErrorCode, str]] = [
    (AiKeyInvalid, "key_invalid", 422, ErrorCode.AI_KEY_INVALID,
     "Tu clave de IA no es válida. Revísala en ajustes."),
    (AiQuotaExceeded, "quota_exceeded", 429, ErrorCode.AI_QUOTA_EXCEEDED,
     "Has alcanzado el límite de tu cuenta del proveedor."),
    (AiResponseInvalid, "invalid_response", 422, ErrorCode.AI_RESPONSE_INVALID,
     "El análisis no ha podido completarse. Puedes reintentar o continuar a mano."),
    (AiUnrecognized, "unrecognized", 422, ErrorCode.AI_UNRECOGNIZED,
     "No se ha reconocido ningún alimento en la foto. Puedes continuar a mano."),
    (AiTimeout, "timeout", 504, ErrorCode.AI_TIMEOUT,
     "El análisis ha tardado demasiado. Puedes reintentar."),
    (AiProviderUnavailable, "provider_error", 503, ErrorCode.AI_PROVIDER_UNAVAILABLE,
     "El proveedor de IA no responde. Inténtalo más tarde."),
]  # fmt: skip


def _status(row) -> AiKeyStatus:
    return AiKeyStatus(provider=row.provider, configured_at=row.configured_at)


async def save_key(
    session: AsyncSession,
    user_id: uuid.UUID,
    raw_key: str,
    ai_provider: AiProvider,
    master_b64: str,
    now: datetime,
) -> AiKeyStatus:
    try:
        await ai_provider.validate_key(raw_key)
    except AiKeyInvalid:
        raise ApiError(
            422, ErrorCode.AI_KEY_INVALID, "La clave no es válida. Revísala e inténtalo de nuevo."
        ) from None
    except AiProviderUnavailable:
        raise ApiError(
            503,
            ErrorCode.AI_PROVIDER_UNAVAILABLE,
            "No se ha podido comprobar la clave ahora. Inténtalo más tarde.",
        ) from None
    row = await repository.upsert_key(
        session, user_id, PROVIDER, crypto.encrypt_key(raw_key, master_b64), now
    )
    return _status(row)


async def get_key_status(session: AsyncSession, user_id: uuid.UUID) -> AiKeyStatus:
    row = await repository.get_key(session, user_id)
    if row is None:
        raise ApiError(404, ErrorCode.AI_KEY_NOT_FOUND, "No tienes una clave de IA configurada.")
    return _status(row)


async def delete_key(session: AsyncSession, user_id: uuid.UUID) -> None:
    await repository.delete_key(session, user_id)


async def analyze_photo(
    session: AsyncSession,
    user_id: uuid.UUID,
    ai_provider: AiProvider,
    master_b64: str,
    model: str,
    photo: bytes,
    description: str | None,
    total_grams: int | None,
) -> PhotoAnalysisResult:
    row = await repository.get_key(session, user_id)
    if row is None:
        raise ApiError(
            403, ErrorCode.AI_KEY_REQUIRED, "Configura tu clave de IA para registrar con foto."
        )
    raw_key = crypto.decrypt_key(row.encrypted_key, master_b64)
    start = time.monotonic()

    def log(result: str) -> None:
        get_logger().info(
            "ai_analysis",
            user_id=str(user_id),
            result=result,
            model=model,
            duration_ms=int((time.monotonic() - start) * 1000),
        )

    try:
        text = await ai_provider.analyze_photo(
            raw_key, photo, build_prompt(description, total_grams)
        )
        raw_items = parse_response(text)
    except Exception as exc:
        for exc_type, result, status, code, message in _FAILURES:
            if isinstance(exc, exc_type):
                log(result)
                raise ApiError(status, code, message) from None
        raise
    items = await match_items(session, user_id, raw_items)
    log("success")
    return PhotoAnalysisResult(items=items)
