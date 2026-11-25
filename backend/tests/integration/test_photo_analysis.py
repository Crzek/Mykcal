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
