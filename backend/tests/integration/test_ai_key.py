"""T016 (006): guardar, consultar, sustituir y quitar la clave de IA."""

import pytest
from sqlalchemy import text

KEY = {"raw_key": "AIzaSyClaveDePrueba1234567890"}


@pytest.fixture
async def user(user_with_consent):
    return await user_with_consent("ai-key-user")


async def test_ciclo_completo(client, user):
    _, h = user
    assert (await client.get("/v1/ai-key", headers=h)).status_code == 404
    put = await client.put("/v1/ai-key", headers=h, json=KEY)
    assert put.status_code == 200, put.text
    assert put.json()["has_key"] is True and put.json()["provider"] == "gemini"
    first = put.json()["configured_at"]
    got = await client.get("/v1/ai-key", headers=h)
    assert got.status_code == 200 and got.json()["configured_at"] == first
    again = await client.put("/v1/ai-key", headers=h, json={"raw_key": "otra-clave"})
    assert again.json()["configured_at"] > first
    assert (await client.delete("/v1/ai-key", headers=h)).status_code == 204
    gone = await client.get("/v1/ai-key", headers=h)
    assert gone.status_code == 404 and gone.json()["code"] == "AI_KEY_NOT_FOUND"
    assert (await client.delete("/v1/ai-key", headers=h)).status_code == 204  # idempotente


async def test_clave_invalida_no_se_guarda(client, user, ai):
    _, h = user
    ai.validate_outcome = "invalid"
    resp = await client.put("/v1/ai-key", headers=h, json=KEY)
    assert resp.status_code == 422 and resp.json()["code"] == "AI_KEY_INVALID"
    assert (await client.get("/v1/ai-key", headers=h)).status_code == 404


async def test_proveedor_caido(client, user, ai):
    _, h = user
    ai.validate_outcome = "unavailable"
    resp = await client.put("/v1/ai-key", headers=h, json=KEY)
    assert resp.status_code == 503 and resp.json()["code"] == "AI_PROVIDER_UNAVAILABLE"


async def test_clave_se_guarda_cifrada(app, client, user):
    _, h = user
    await client.put("/v1/ai-key", headers=h, json=KEY)
    async with app.state.sessionmaker() as s:
        blob = (await s.execute(text("SELECT encrypted_key FROM ai_key"))).scalar_one()
    assert KEY["raw_key"].encode() not in bytes(blob)


@pytest.mark.parametrize(
    "body", [{}, {"raw_key": ""}, {"raw_key": "x" * 257}, {"raw_key": "a", "x": 1}]
)
async def test_cuerpo_no_valido(client, user, body):
    _, h = user
    assert (await client.put("/v1/ai-key", headers=h, json=body)).status_code == 400


async def test_borrar_y_volver_a_guardar_relista(client, user, ai):
    _, h = user
    photo = {"photo": ("p.jpg", b"\xff\xd8x", "image/jpeg")}
    form = {"meal": "lunch", "entry_date": "2026-01-01"}
    await client.put("/v1/ai-key", headers=h, json=KEY)
    await client.post("/v1/photo-analysis", headers=h, files=photo, data=form)
    await client.post("/v1/photo-analysis", headers=h, files=photo, data=form)
    assert ai.list_calls == 1
    await client.delete("/v1/ai-key", headers=h)
    await client.put("/v1/ai-key", headers=h, json=KEY)
    await client.post("/v1/photo-analysis", headers=h, files=photo, data=form)
    assert ai.list_calls == 2


async def test_cambiar_la_clave_lista_con_la_nueva(client, user, ai):
    _, h = user
    photo = {"photo": ("p.jpg", b"\xff\xd8x", "image/jpeg")}
    form = {"meal": "lunch", "entry_date": "2026-01-01"}
    await client.put("/v1/ai-key", headers=h, json=KEY)
    await client.post("/v1/photo-analysis", headers=h, files=photo, data=form)
    await client.put("/v1/ai-key", headers=h, json={"raw_key": "otra-clave"})
    await client.post("/v1/photo-analysis", headers=h, files=photo, data=form)
    assert ai.list_calls == 2


async def test_guardar_clave_no_depende_de_ningun_modelo(client, user, ai):
    _, h = user
    ai.models = ["gemini-3.6-flash"]
    ai.model_outcomes = {"gemini-3.6-flash": "overloaded"}
    ai.analyze_outcome = "unavailable"
    assert (await client.put("/v1/ai-key", headers=h, json=KEY)).status_code == 200
    assert ai.models_tried == []
    ai.validate_outcome = "invalid"
    resp = await client.put("/v1/ai-key", headers=h, json=KEY)
    assert resp.status_code == 422 and resp.json()["code"] == "AI_KEY_INVALID"
