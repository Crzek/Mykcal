"""T018 (006): B nunca ve, usa ni toca la clave de A."""

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]


@pytest.fixture
async def two(user_with_consent):
    return await user_with_consent("ai-a"), await user_with_consent("ai-b")


async def test_clave_de_a_invisible_para_b(client, two):
    (_, ha), (_, hb) = two
    await client.put("/v1/ai-key", headers=ha, json={"raw_key": "clave-de-a"})
    assert (await client.get("/v1/ai-key", headers=hb)).status_code == 404
    await client.put("/v1/ai-key", headers=hb, json={"raw_key": "clave-de-b"})
    a = (await client.get("/v1/ai-key", headers=ha)).json()
    assert a["has_key"] is True
    assert (await client.delete("/v1/ai-key", headers=hb)).status_code == 204
    assert (await client.get("/v1/ai-key", headers=ha)).status_code == 200
    assert (await client.get("/v1/ai-key", headers=hb)).status_code == 404


async def test_b_sin_clave_no_analiza_aunque_a_tenga(client, two):
    (_, ha), (_, hb) = two
    await client.put("/v1/ai-key", headers=ha, json={"raw_key": "clave-de-a"})
    resp = await client.post(
        "/v1/photo-analysis",
        headers=hb,
        files={"photo": ("p.jpg", b"\xff\xd8x", "image/jpeg")},
        data={"meal": "lunch", "entry_date": "2026-01-01"},
    )
    assert resp.status_code == 403 and resp.json()["code"] == "AI_KEY_REQUIRED"
