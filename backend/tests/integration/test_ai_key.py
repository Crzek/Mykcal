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
