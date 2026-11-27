"""Proveedor Gemini por HTTP (research R4). La clave va en cabecera, nunca en la URL."""

from __future__ import annotations

import base64
from typing import Any

import httpx

from mykcal.ai.provider import (
    AiKeyInvalid,
    AiModelNotFound,
    AiProvider,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
    ModelInfo,
)
from mykcal.logging import get_logger

BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
VALIDATE_TIMEOUT_S = 10.0
MAX_LIST_PAGES = 3


def _google_status(resp: httpx.Response) -> str:
    try:
        status = resp.json()["error"]["status"]
    except (ValueError, KeyError, TypeError):
        return "unknown"
    return status if isinstance(status, str) and status.isupper() else "unknown"


class GeminiProvider(AiProvider):
    """Sin estado: el modelo y el tiempo de cada llamada los decide el selector."""

    async def _request(
        self,
        method: str,
        raw_key: str,
        url: str,
        timeout: float,
        *,
        body: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                resp = await client.request(
                    method, url, json=body, params=params, headers={"x-goog-api-key": raw_key}
                )
        except httpx.TimeoutException as exc:
            raise AiTimeout from exc
        except httpx.HTTPError as exc:
            get_logger().warning("ai_provider_error", error_class=type(exc).__name__)
            raise AiProviderUnavailable from exc
        if resp.status_code in (400, 401, 403):
            # Gemini responde 400 «API key not valid» a una clave mal escrita.
            raise AiKeyInvalid
        if resp.status_code == 429:
            raise AiQuotaExceeded
        if resp.status_code != 200:
            # Solo el código HTTP y el estado de Google (p. ej. NOT_FOUND); nunca el cuerpo.
            get_logger().warning(
                "ai_provider_error", status=resp.status_code, result=_google_status(resp)
            )
            if resp.status_code == 404:
                raise AiModelNotFound
            raise AiProviderUnavailable(overloaded=resp.status_code == 503)
        try:
            return resp.json()
        except ValueError as exc:
            raise AiProviderUnavailable from exc

    async def list_models(self, raw_key: str, timeout_s: float) -> list[ModelInfo]:
        models: list[ModelInfo] = []
        token: str | None = None
        for _ in range(MAX_LIST_PAGES):
            params: dict[str, Any] = {"pageSize": 1000}
            if token:
                params["pageToken"] = token
            data = await self._request("GET", raw_key, BASE_URL, timeout_s, params=params)
            for item in data.get("models", []) if isinstance(data, dict) else []:
                name = item.get("name") if isinstance(item, dict) else None
                if not isinstance(name, str):
                    continue
                methods = item.get("supportedGenerationMethods") or []
                models.append(ModelInfo(name.removeprefix("models/"), "generateContent" in methods))
            token = data.get("nextPageToken") if isinstance(data, dict) else None
            if not token:
                break
        return models

    async def validate_key(self, raw_key: str) -> None:
        # Listar modelos autentica la clave sin cargar ningún modelo: una saturación del modelo de
        # análisis (503 «high demand») no debe impedir guardar una clave válida.
        try:
            async with httpx.AsyncClient(timeout=VALIDATE_TIMEOUT_S) as client:
                resp = await client.get(
                    BASE_URL, params={"pageSize": 1}, headers={"x-goog-api-key": raw_key}
                )
        except httpx.HTTPError as exc:
            get_logger().warning("ai_provider_error", error_class=type(exc).__name__)
            raise AiProviderUnavailable from exc
        if resp.status_code in (400, 401, 403):
            raise AiKeyInvalid
        if resp.status_code == 429:
            return  # la clave existe y es válida: solo está sin cuota ahora mismo
        if resp.status_code != 200:
            get_logger().warning(
                "ai_provider_error", status=resp.status_code, result=_google_status(resp)
            )
            raise AiProviderUnavailable

    async def analyze_photo(
        self, raw_key: str, model: str, image: bytes, prompt: str, timeout_s: float
    ) -> str:
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
        data = await self._request(
            "POST", raw_key, f"{BASE_URL}/{model}:generateContent", timeout_s, body=body
        )
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError):
            return ""  # sin texto: `parse_response` lo trata como respuesta inválida
