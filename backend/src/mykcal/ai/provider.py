"""Contrato del proveedor de IA (research R4): lo que el resto del backend conoce de Gemini."""

from __future__ import annotations

from abc import ABC, abstractmethod


class AiKeyInvalid(Exception):
    """El proveedor rechaza la clave (revocada o mal escrita)."""


class AiQuotaExceeded(Exception):
    """Cuota o límite de la cuenta del proveedor agotado."""


class AiProviderUnavailable(Exception):
    """El proveedor no responde o falla (5xx, red)."""


class AiTimeout(Exception):
    """El análisis superó el tiempo máximo."""


class AiProvider(ABC):
    @abstractmethod
    async def validate_key(self, raw_key: str) -> None:
        """Lanza `AiKeyInvalid` o `AiProviderUnavailable` si no se puede usar."""

    @abstractmethod
    async def analyze_photo(self, raw_key: str, image: bytes, prompt: str) -> str:
        """Devuelve el texto crudo de la respuesta (la validación es de `prompt.parse_response`)."""
