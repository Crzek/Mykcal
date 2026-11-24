from __future__ import annotations

from enum import StrEnum
from typing import Any

from pydantic import BaseModel


class ErrorCode(StrEnum):
    UNAUTHORIZED = "UNAUTHORIZED"
    AUTH_UNAVAILABLE = "AUTH_UNAVAILABLE"
    ACCOUNT_NOT_REGISTERED = "ACCOUNT_NOT_REGISTERED"
    ACCOUNT_DISABLED = "ACCOUNT_DISABLED"
    FORBIDDEN = "FORBIDDEN"
    ALREADY_REGISTERED = "ALREADY_REGISTERED"
    INVITATION_INVALID = "INVITATION_INVALID"
    INVITATION_REQUIRED = "INVITATION_REQUIRED"
    NO_SEATS = "NO_SEATS"
    TOO_MANY_ATTEMPTS = "TOO_MANY_ATTEMPTS"
    CONSENT_REQUIRED = "CONSENT_REQUIRED"
    CONSENT_VERSION_MISMATCH = "CONSENT_VERSION_MISMATCH"
    PROFILE_NOT_FOUND = "PROFILE_NOT_FOUND"
    PROFILE_REQUIRED = "PROFILE_REQUIRED"
    TARGET_NOT_FOUND = "TARGET_NOT_FOUND"
    FOOD_NOT_FOUND = "FOOD_NOT_FOUND"
    FOOD_BARCODE_TAKEN = "FOOD_BARCODE_TAKEN"
    FOOD_SOURCE_UNAVAILABLE = "FOOD_SOURCE_UNAVAILABLE"
    DIARY_DATE_OUT_OF_RANGE = "DIARY_DATE_OUT_OF_RANGE"
    ENTRY_NOT_FOUND = "ENTRY_NOT_FOUND"
    COPY_SOURCE_EMPTY = "COPY_SOURCE_EMPTY"
    COPY_NOT_FOUND = "COPY_NOT_FOUND"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    INTERNAL_ERROR = "INTERNAL_ERROR"


class ErrorBody(BaseModel):
    code: ErrorCode
    message: str
    retry_after_s: int | None = None
    # Solo con VALIDATION_ERROR: nombres de campo, nunca valores (research R14).
    fields: list[str] | None = None


class ApiError(Exception):
    def __init__(
        self,
        status: int,
        code: ErrorCode,
        message: str,
        *,
        retry_after_s: int | None = None,
        headers: dict[str, str] | None = None,
        fields: list[str] | None = None,
    ) -> None:
        super().__init__(code.value)
        self.status = status
        self.code = code
        self.message = message
        self.retry_after_s = retry_after_s
        self.fields = fields
        self.headers = headers or {}
        if retry_after_s is not None:
            self.headers.setdefault("Retry-After", str(retry_after_s))

    def body(self) -> dict[str, Any]:
        return ErrorBody(
            code=self.code,
            message=self.message,
            retry_after_s=self.retry_after_s,
            fields=self.fields,
        ).model_dump(exclude_none=True, mode="json")


def unauthorized() -> ApiError:
    return ApiError(
        401,
        ErrorCode.UNAUTHORIZED,
        "Sesión no válida o caducada.",
        headers={"WWW-Authenticate": 'Bearer error="invalid_token"'},
    )
