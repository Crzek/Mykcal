"""T020/T040 (006): las respuestas de la clave y del análisis validan contra 0.6.0."""

import pytest

from tests.contract.schema import assert_matches_contract


@pytest.fixture
async def user(user_with_consent):
    return await user_with_consent("ai-contract")


def photo():
    return {
        "files": {"photo": ("p.jpg", b"\xff\xd8x", "image/jpeg")},
        "data": {"meal": "lunch", "entry_date": "2026-01-01"},
    }


async def test_ai_key(client, user, ai, contract):
    _, h = user
    r = await client.get("/v1/ai-key", headers=h)
    assert_matches_contract(contract, "/v1/ai-key", "get", 404, r.json())
    r = await client.put("/v1/ai-key", headers=h, json={"raw_key": "k"})
    assert_matches_contract(contract, "/v1/ai-key", "put", 200, r.json())
    r = await client.get("/v1/ai-key", headers=h)
    assert_matches_contract(contract, "/v1/ai-key", "get", 200, r.json())
    ai.validate_outcome = "invalid"
    r = await client.put("/v1/ai-key", headers=h, json={"raw_key": "k"})
    assert_matches_contract(contract, "/v1/ai-key", "put", 422, r.json())
    ai.validate_outcome = "unavailable"
    r = await client.put("/v1/ai-key", headers=h, json={"raw_key": "k"})
    assert_matches_contract(contract, "/v1/ai-key", "put", 503, r.json())
    assert (await client.delete("/v1/ai-key", headers=h)).status_code == 204


async def test_photo_analysis(client, user, ai, make_food, contract):
    _, h = user
    await make_food("Arroz blanco cocido")
    await client.put("/v1/ai-key", headers=h, json={"raw_key": "k"})
    r = await client.post("/v1/photo-analysis", headers=h, **photo())
    assert r.status_code == 200, r.text
    assert_matches_contract(contract, "/v1/photo-analysis", "post", 200, r.json())
    assert r.json()["items"][0]["matched_food"] is not None
    for outcome, status in (("quota_exceeded", 429), ("empty_items", 422), ("timeout", 504)):
        ai.analyze_outcome = outcome
        r = await client.post("/v1/photo-analysis", headers=h, **photo())
        assert_matches_contract(contract, "/v1/photo-analysis", "post", status, r.json())
