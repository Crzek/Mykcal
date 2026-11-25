"""Proveedor Gemini por HTTP (research R4). La clave va en cabecera, nunca en la URL."""

from __future__ import annotations

import base64
from typing import Any

import httpx

from mykcal.ai.provider import (
    AiKeyInvalid,
    AiProvider,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
)

BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
VALIDATE_TIMEOUT_S = 10.0


class GeminiProvider(AiProvider):
    def __init__(self, model: str, timeout_s: float) -> None:
        self._url = f"{BASE_URL}/{model}:generateContent"
        self._timeout_s = timeout_s

    async def _post(self, raw_key: str, body: dict[str, Any], timeout: float) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                resp = await client.post(self._url, json=body, headers={"x-goog-api-key": raw_key})
        except httpx.TimeoutException as exc:
            raise AiTimeout from exc
        except httpx.HTTPError as exc:
            raise AiProviderUnavailable from exc
        if resp.status_code in (400, 401, 403):
            # Gemini responde 400 «API key not valid» a una clave mal escrita.
            raise AiKeyInvalid
        if resp.status_code == 429:
            raise AiQuotaExceeded
        if resp.status_code >= 500 or resp.status_code != 200:
            raise AiProviderUnavailable
        try:
            return resp.json()
        except ValueError as exc:
            raise AiProviderUnavailable from exc

    async def validate_key(self, raw_key: str) -> None:
        body = {
            "contents": [{"parts": [{"text": "ping"}]}],
            "generationConfig": {"maxOutputTokens": 1},
        }
        try:
            await self._post(raw_key, body, VALIDATE_TIMEOUT_S)
        except AiTimeout as exc:
            raise AiProviderUnavailable from exc
        except AiQuotaExceeded:
            return  # la clave existe y es válida: solo está sin cuota ahora mismo

    async def analyze_photo(self, raw_key: str, image: bytes, prompt: str) -> str:
        body = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt},
                        {
                            "inlineData": {
                                "mimeType": "image/jpeg",
                                "data": base64.b64encode(image).decode(),
                            }
                        },
                    ]
                }
            ],
            "generationConfig": {"responseMimeType": "application/json"},
        }
        data = await self._post(raw_key, body, self._timeout_s)
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError):
            return ""  # sin texto: `parse_response` lo trata como respuesta inválida
