"""`GeminiProvider.validate_key` autentica sin cargar el modelo de análisis."""

from __future__ import annotations

import httpx
import pytest

from mykcal.ai import gemini
from mykcal.ai.gemini import GeminiProvider
from mykcal.ai.provider import (
    AiKeyInvalid,
    AiModelNotFound,
    AiProviderUnavailable,
    AiQuotaExceeded,
)


def _patch(monkeypatch: pytest.MonkeyPatch, handler) -> list[httpx.Request]:
    seen: list[httpx.Request] = []

    def wrapped(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return handler(request)

    real = httpx.AsyncClient
    monkeypatch.setattr(
        gemini.httpx,
        "AsyncClient",
        lambda **kw: real(transport=httpx.MockTransport(wrapped), **kw),
    )
    return seen


async def test_valid_key_does_not_call_the_model(monkeypatch: pytest.MonkeyPatch) -> None:
    seen = _patch(monkeypatch, lambda r: httpx.Response(200, json={"models": []}))
    await GeminiProvider().validate_key("k")
    assert len(seen) == 1
    assert seen[0].method == "GET"
    assert "generateContent" not in str(seen[0].url)
    assert seen[0].headers["x-goog-api-key"] == "k"
    assert "key=" not in str(seen[0].url)  # la clave va en cabecera, nunca en la URL


async def test_bad_key_is_invalid(monkeypatch: pytest.MonkeyPatch) -> None:
    _patch(
        monkeypatch, lambda r: httpx.Response(400, json={"error": {"status": "INVALID_ARGUMENT"}})
    )
    with pytest.raises(AiKeyInvalid):
        await GeminiProvider().validate_key("bad")


async def test_provider_outage_is_unavailable(monkeypatch: pytest.MonkeyPatch) -> None:
    _patch(monkeypatch, lambda r: httpx.Response(503, json={"error": {"status": "UNAVAILABLE"}}))
    with pytest.raises(AiProviderUnavailable):
        await GeminiProvider().validate_key("k")


async def test_quota_exceeded_still_accepts_the_key(monkeypatch: pytest.MonkeyPatch) -> None:
    _patch(monkeypatch, lambda r: httpx.Response(429))
    await GeminiProvider().validate_key("k")


async def test_list_models_pagina_quita_prefijo_y_marca_generate_content(monkeypatch):
    pages = {
        None: {
            "models": [
                {
                    "name": "models/gemini-3.6-flash",
                    "supportedGenerationMethods": ["generateContent"],
                },
                {
                    "name": "models/text-embedding-004",
                    "supportedGenerationMethods": ["embedContent"],
                },
            ],
            "nextPageToken": "p2",
        },
        "p2": {"models": [{"name": "models/gemini-3.6-flash-lite"}]},
    }
    seen = _patch(
        monkeypatch, lambda r: httpx.Response(200, json=pages[r.url.params.get("pageToken")])
    )
    models = await GeminiProvider().list_models("k", 5)
    assert [(m.name, m.generate_content) for m in models] == [
        ("gemini-3.6-flash", True),
        ("text-embedding-004", False),
        ("gemini-3.6-flash-lite", False),
    ]
    assert seen[0].url.params["pageSize"] == "1000"
    assert seen[0].headers["x-goog-api-key"] == "k" and "key=" not in str(seen[0].url)


@pytest.mark.parametrize(
    ("status", "exc", "overloaded"),
    [
        (404, AiModelNotFound, None),
        (503, AiProviderUnavailable, True),
        (500, AiProviderUnavailable, False),
        (429, AiQuotaExceeded, None),
        (403, AiKeyInvalid, None),
    ],
)
async def test_analyze_photo_mapea_errores(monkeypatch, status, exc, overloaded):
    seen = _patch(monkeypatch, lambda r: httpx.Response(status, json={}))
    with pytest.raises(exc) as info:
        await GeminiProvider().analyze_photo("k", "gemini-x", b"img", "p", 5)
    assert str(seen[0].url).endswith("/models/gemini-x:generateContent")
    if overloaded is not None:
        assert info.value.overloaded is overloaded
