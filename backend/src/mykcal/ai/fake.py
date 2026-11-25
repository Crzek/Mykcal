"""Proveedor simulado: las pruebas nunca salen a la red (principio VI, FR-019)."""

from __future__ import annotations

from typing import Literal

from mykcal.ai.provider import (
    AiKeyInvalid,
    AiProvider,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
)

DEFAULT_RESPONSE = '{"items": [{"name": "Arroz blanco cocido", "grams": 150}]}'


class FakeProvider(AiProvider):
    def __init__(self) -> None:
        self.validate_outcome: Literal["ok", "invalid", "unavailable"] = "ok"
        self.analyze_outcome: Literal[
            "success",
            "key_invalid",
            "quota_exceeded",
            "invalid_json",
            "empty_items",
            "timeout",
            "unavailable",
        ] = "success"
        self.response_json: str | None = None
        self.calls: list[tuple[str, int, str]] = []

    async def validate_key(self, raw_key: str) -> None:
        if self.validate_outcome == "invalid":
            raise AiKeyInvalid
        if self.validate_outcome == "unavailable":
            raise AiProviderUnavailable

    async def analyze_photo(self, raw_key: str, image: bytes, prompt: str) -> str:
        self.calls.append((raw_key, len(image), prompt))
        match self.analyze_outcome:
            case "key_invalid":
                raise AiKeyInvalid
            case "quota_exceeded":
                raise AiQuotaExceeded
            case "timeout":
                raise AiTimeout
            case "unavailable":
                raise AiProviderUnavailable
            case "invalid_json":
                return "esto no es json"
            case "empty_items":
                return '{"items": []}'
        return self.response_json or DEFAULT_RESPONSE
