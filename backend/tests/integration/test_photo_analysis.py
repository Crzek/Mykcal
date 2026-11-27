"""T038/T061 (006): análisis de foto, camino feliz y cada causa de fallo (research R11)."""

import json

import pytest

PHOTO = b"\xff\xd8\xff-foto-de-prueba"


@pytest.fixture
async def user(user_with_consent, client, make_food):
    _, h = await user_with_consent("photo-user")
    await make_food("Arroz blanco cocido", kcal=130)
    await client.put("/v1/ai-key", headers=h, json={"raw_key": "clave-de-prueba"})
    return h


async def analyze(client, h, photo=PHOTO, **data):
    return await client.post(
        "/v1/photo-analysis",
        headers=h,
        files={"photo": ("p.jpg", photo, "image/jpeg")},
        data={"meal": "lunch", "entry_date": "2026-01-01", **data},
    )


async def test_camino_feliz(client, user, ai):
    resp = await analyze(client, user, description="arroz", total_grams="300")
    assert resp.status_code == 200, resp.text
    (item,) = resp.json()["items"]
    assert item["matched_food"]["name"] == "Arroz blanco cocido" and item["kcal"] == 195.0
    raw_key, size, prompt = ai.calls[-1]
    assert raw_key == "clave-de-prueba" and size == len(PHOTO)
    assert "arroz" in prompt and "300" in prompt


async def test_sin_clave_403(client, user_with_consent):
    _, h = await user_with_consent("photo-nokey")
    resp = await analyze(client, h)
    assert resp.status_code == 403 and resp.json()["code"] == "AI_KEY_REQUIRED"


async def test_foto_de_mas_de_4mb_413(client, user):
    resp = await analyze(client, user, photo=b"x" * (4 * 1024 * 1024 + 1))
    assert resp.status_code == 413


async def test_campos_no_validos_400(client, user):
    assert (await analyze(client, user, meal="brunch")).status_code == 400
    assert (await analyze(client, user, total_grams="0")).status_code == 400


@pytest.mark.parametrize(
    ("outcome", "status", "code", "result"),
    [
        ("key_invalid", 422, "AI_KEY_INVALID", "key_invalid"),
        ("quota_exceeded", 429, "AI_QUOTA_EXCEEDED", "quota_exceeded"),
        ("invalid_json", 422, "AI_RESPONSE_INVALID", "invalid_response"),
        ("empty_items", 422, "AI_UNRECOGNIZED", "unrecognized"),
        ("timeout", 504, "AI_TIMEOUT", "timeout"),
        ("unavailable", 503, "AI_PROVIDER_UNAVAILABLE", "provider_error"),
    ],
)
async def test_cada_fallo_tiene_su_codigo_y_su_registro(
    client, user, ai, capsys, outcome, status, code, result
):
    ai.analyze_outcome = outcome
    capsys.readouterr()
    resp = await analyze(client, user)
    assert resp.status_code == status and resp.json()["code"] == code
    events = [json.loads(line) for line in capsys.readouterr().out.splitlines() if line.strip()]
    (event,) = [e for e in events if e["event"] == "ai_analysis"]
    assert event["result"] == result and event["model"] and "duration_ms" in event


def _events(capsys, name):
    out = capsys.readouterr().out
    return [
        e
        for line in out.splitlines()
        if line.strip()
        for e in [json.loads(line)]
        if e["event"] == name
    ]


async def test_sin_preferencia_usa_el_modelo_listado(client, user, ai):
    assert (await analyze(client, user)).status_code == 200
    assert ai.models_tried == ["gemini-3.6-flash"]


async def test_modelo_preferido_retirado_cae_a_otro(client, user, ai, app, capsys):
    from mykcal.ai.model_selector import ModelSelector

    app.state.model_selector = ModelSelector(ai, ["gemini-1.0-flash"])
    capsys.readouterr()
    resp = await analyze(client, user)
    assert resp.status_code == 200
    (event,) = _events(capsys, "ai_analysis")
    assert event["selection"] == "fallback" and event["model"] == "gemini-3.6-flash"


async def test_sin_modelo_compatible_503(client, user, ai, capsys):
    ai.models = ["gemini-3.6-pro"]
    capsys.readouterr()
    resp = await analyze(client, user)
    assert resp.status_code == 503 and resp.json()["code"] == "AI_NO_MODEL_AVAILABLE"
    (event,) = _events(capsys, "ai_analysis")
    assert event["result"] == "no_model" and "model" not in event


async def test_404_a_mitad_prueba_el_siguiente_y_relista(client, user, ai):
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = {"gemini-3.6-flash-lite": "not_found"}
    resp = await analyze(client, user)
    assert resp.status_code == 200
    assert ai.models_tried == ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    assert ai.list_calls == 2


@pytest.mark.parametrize("first", ["overloaded", "quota"])
async def test_saturado_o_sin_cuota_prueba_el_siguiente(client, user, ai, first):
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = {"gemini-3.6-flash-lite": first}
    assert (await analyze(client, user)).status_code == 200
    assert ai.models_tried == ["gemini-3.6-flash-lite", "gemini-3.6-flash"]


@pytest.mark.parametrize(
    ("outcome", "status", "code"),
    [
        ("overloaded", 503, "AI_PROVIDER_UNAVAILABLE"),
        ("quota", 429, "AI_QUOTA_EXCEEDED"),
        ("timeout", 504, "AI_TIMEOUT"),
    ],
)
async def test_todos_fallan_error_final(client, user, ai, outcome, status, code):
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = dict.fromkeys(ai.models, outcome)
    resp = await analyze(client, user)
    assert resp.status_code == status and resp.json()["code"] == code


async def test_respuesta_invalida_no_cambia_de_modelo(client, user, ai):
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.analyze_outcome = "invalid_json"
    resp = await analyze(client, user)
    assert resp.status_code == 422 and resp.json()["code"] == "AI_RESPONSE_INVALID"
    assert len(ai.models_tried) == 1


async def test_valor_unico_antiguo_de_ai_model_sigue_funcionando(client, user, ai, app):
    from mykcal.ai.model_selector import ModelSelector

    app.state.model_selector = ModelSelector(ai, ["gemini-3.6-flash"])
    assert (await analyze(client, user)).status_code == 200
    assert ai.models_tried == ["gemini-3.6-flash"]
