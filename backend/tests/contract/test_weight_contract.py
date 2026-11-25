"""T017/T027/T038 (007): peso, gráfica y propuesta validan contra el contrato 0.7.0."""

from datetime import UTC, datetime, timedelta

import pytest

from tests.contract.schema import assert_matches_contract

NOW = datetime.now(UTC)
TODAY = NOW.date()
OFF = {"utc_offset_min": 0}


@pytest.fixture
async def user(user_with_consent, make_target_version, make_profile):
    account, headers = await user_with_consent("weight-contract")
    await make_target_version(account, NOW - timedelta(days=30))
    await make_profile(account)
    return account, headers


async def test_crud_de_peso(client, user, contract):
    _, h = user
    body = {"measured_on": TODAY.isoformat(), "weight_kg": 78.4}
    post = await client.post("/v1/weight", json=body, params=OFF, headers=h)
    assert_matches_contract(contract, "/v1/weight", "post", 200, post.json())
    listed = await client.get("/v1/weight", headers=h)
    assert_matches_contract(contract, "/v1/weight", "get", 200, listed.json())
    put = await client.put(f"/v1/weight/{TODAY}", json={"weight_kg": 78.0}, params=OFF, headers=h)
    assert_matches_contract(contract, "/v1/weight/{date}", "put", 200, put.json())
    bad = await client.post("/v1/weight", json=body | {"weight_kg": 5}, params=OFF, headers=h)
    assert_matches_contract(contract, "/v1/weight", "post", 400, bad.json())
    gone = await client.delete(f"/v1/weight/{TODAY - timedelta(days=1)}", params=OFF, headers=h)
    assert_matches_contract(contract, "/v1/weight/{date}", "delete", 404, gone.json())
    done = await client.delete(f"/v1/weight/{TODAY}", params=OFF, headers=h)
    assert done.status_code == 204
    assert_matches_contract(contract, "/v1/weight/{date}", "delete", 204, None)


async def test_grafica(client, user, make_weight, contract):
    account, h = user
    for ago in range(4):
        await make_weight(account, TODAY - timedelta(days=ago), 78 + ago / 10)
    resp = await client.get("/v1/weight/chart", params={"period": "p30", **OFF}, headers=h)
    assert resp.status_code == 200
    assert_matches_contract(contract, "/v1/weight/chart", "get", 200, resp.json())


async def test_propuesta_pending_none_aceptar_e_ignorar(client, user, make_weight, contract):
    account, h = user
    none = await client.get("/v1/recalc-proposal", params=OFF, headers=h)
    assert none.json() == {"status": "none"}
    assert_matches_contract(contract, "/v1/recalc-proposal", "get", 200, none.json())
    for ago in range(3):
        await make_weight(account, TODAY - timedelta(days=ago), 78.2)
    pending = await client.get("/v1/recalc-proposal", params=OFF, headers=h)
    assert pending.json()["status"] == "pending"
    assert_matches_contract(contract, "/v1/recalc-proposal", "get", 200, pending.json())
    accepted = await client.post("/v1/recalc-proposal/accept", params=OFF, headers=h)
    assert accepted.status_code == 200
    assert_matches_contract(contract, "/v1/recalc-proposal/accept", "post", 200, accepted.json())
    again = await client.post("/v1/recalc-proposal/ignore", params=OFF, headers=h)
    assert again.status_code == 409 and again.json()["code"] == "RECALC_NO_PROPOSAL"
    assert_matches_contract(contract, "/v1/recalc-proposal/ignore", "post", 409, again.json())
