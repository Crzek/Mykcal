"""FR-010 / principio V (007): B nunca ve ni toca el peso ni la gráfica de A."""

from datetime import UTC, datetime, timedelta

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]

NOW = datetime.now(UTC)
TODAY = NOW.date()
OFF = {"utc_offset_min": 0}


@pytest.fixture
async def two_users(user_with_consent, make_target_version):
    a, ha = await user_with_consent("weight-a")
    b, hb = await user_with_consent("weight-b")
    for account in (a, b):
        await make_target_version(account, NOW - timedelta(days=30))
    return (a, ha), (b, hb)


async def test_b_no_ve_los_pesos_de_a(client, two_users, make_weight):
    (a, ha), (b, hb) = two_users
    await make_weight(a, TODAY, 91.3)
    await make_weight(b, TODAY, 62.1)
    resp = await client.get("/v1/weight", headers=hb)
    assert [e["weight_kg"] for e in resp.json()["entries"]] == [62.1]
    assert "91.3" not in resp.text
    mine = await client.get("/v1/weight", headers=ha)
    assert [e["weight_kg"] for e in mine.json()["entries"]] == [91.3]


async def test_b_no_modifica_ni_borra_lo_de_a(client, two_users, make_weight):
    (a, ha), (_, hb) = two_users
    day = TODAY - timedelta(days=1)
    await make_weight(a, day, 91.3)
    put = await client.put(f"/v1/weight/{day}", json={"weight_kg": 50}, params=OFF, headers=hb)
    delete = await client.delete(f"/v1/weight/{day}", params=OFF, headers=hb)
    for resp in (put, delete):
        assert resp.status_code == 404 and resp.json()["code"] == "WEIGHT_NOT_FOUND"
    entries = (await client.get("/v1/weight", headers=ha)).json()["entries"]
    assert [e["weight_kg"] for e in entries] == [91.3]


async def test_la_grafica_de_b_no_incluye_a(client, two_users, make_weight):
    (a, _), (b, hb) = two_users
    for ago in range(3):
        await make_weight(a, TODAY - timedelta(days=ago), 91.3)
    await make_weight(b, TODAY, 62.1)
    resp = await client.get("/v1/weight/chart", params={"period": "all", **OFF}, headers=hb)
    assert [p["weight_kg"] for p in resp.json()["points"]] == [62.1]
    assert "91.3" not in resp.text
