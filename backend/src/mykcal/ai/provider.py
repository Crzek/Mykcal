"""Contrato del proveedor de IA (research R4): lo que el resto del backend conoce de Gemini."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


class AiKeyInvalid(Exception):
    """El proveedor rechaza la clave (revocada o mal escrita)."""


class AiQuotaExceeded(Exception):
    """Cuota o límite de la cuenta del proveedor agotado."""


class AiProviderUnavailable(Exception):
    """El proveedor no responde o falla (5xx, red). `overloaded` marca la saturación (503)."""

    def __init__(self, overloaded: bool = False) -> None:
        super().__init__()
        self.overloaded = overloaded


class AiModelNotFound(Exception):
    """El modelo ya no existe para esta clave (404)."""


class AiNoModelAvailable(Exception):
    """La clave no ve ningún modelo compatible (la lanza el selector)."""


class AiTimeout(Exception):
    """El análisis superó el tiempo máximo."""


@dataclass(frozen=True)
class ModelInfo:
    name: str  # sin el prefijo "models/"
    generate_content: bool


class AiProvider(ABC):
    @abstractmethod
    async def validate_key(self, raw_key: str) -> None:
        """Lanza `AiKeyInvalid` o `AiProviderUnavailable` si no se puede usar."""

    @abstractmethod
    async def list_models(self, raw_key: str, timeout_s: float) -> list[ModelInfo]:
        """Modelos que ve la clave. Lanza `AiKeyInvalid`, `AiTimeout` o `AiProviderUnavailable`."""

    @abstractmethod
    async def analyze_photo(
        self, raw_key: str, model: str, image: bytes, prompt: str, timeout_s: float
    ) -> str:
        """Devuelve el texto crudo de la respuesta (la validación es de `prompt.parse_response`)."""
