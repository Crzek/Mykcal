"""Proveedor simulado: las pruebas nunca salen a la red (principio VI, FR-019)."""

from __future__ import annotations

from typing import Literal

from mykcal.ai.provider import (
    AiKeyInvalid,
    AiModelNotFound,
    AiProvider,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
    ModelInfo,
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
        self.models: list[str] = ["gemini-3.6-flash"]
        self.list_outcome: Literal["ok", "unavailable", "key_invalid"] = "ok"
        # por modelo: "ok", "not_found", "overloaded", "quota", "timeout"; ausente = analyze_outcome
        self.model_outcomes: dict[str, str] = {}
        self.list_calls = 0
        self.models_tried: list[str] = []

    async def validate_key(self, raw_key: str) -> None:
        if self.validate_outcome == "invalid":
            raise AiKeyInvalid
        if self.validate_outcome == "unavailable":
            raise AiProviderUnavailable

    async def list_models(self, raw_key: str, timeout_s: float) -> list[ModelInfo]:
        self.list_calls += 1
        if self.list_outcome == "key_invalid":
            raise AiKeyInvalid
        if self.list_outcome == "unavailable":
            raise AiProviderUnavailable
        return [ModelInfo(name, True) for name in self.models]

    async def analyze_photo(
        self, raw_key: str, model: str, image: bytes, prompt: str, timeout_s: float
    ) -> str:
        self.calls.append((raw_key, len(image), prompt))
        self.models_tried.append(model)
        match self.model_outcomes.get(model):
            case "not_found":
                raise AiModelNotFound
            case "overloaded":
                raise AiProviderUnavailable(overloaded=True)
            case "quota":
                raise AiQuotaExceeded
            case "timeout":
                raise AiTimeout
            case "ok":
                return self.response_json or DEFAULT_RESPONSE
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
