"""T019/T049 (004): las respuestas del diario validan contra openapi.yaml 0.4.0."""

from datetime import UTC, datetime, timedelta

import pytest

from tests.contract.schema import assert_matches_contract

TODAY = datetime.now(UTC).date()


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("diary-contract")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=30))
    return account, headers


async def test_get_day_200(client, user, make_entry, contract):
    account, headers = user
    await make_entry(account, TODAY, "lunch", kcal=250, protein_g=12, fiber_g=3, quantity=120)
    await make_entry(account, TODAY, "snacks", kcal=80, quantity=30)
    resp = await client.get(
        f"/v1/diary/days/{TODAY.isoformat()}?utc_offset_min=60", headers=headers
    )
    assert resp.status_code == 200
    assert_matches_contract(contract, "/v1/diary/days/{date}", "get", 200, resp.json())
    assert len(resp.json()["meals"]) == 5
    assert len(resp.json()["remaining"]) == 12


async def test_get_day_404_sin_objetivo(client, user_with_consent, contract):
    _, headers = await user_with_consent("diary-contract-2")
    resp = await client.get(f"/v1/diary/days/{TODAY.isoformat()}?utc_offset_min=0", headers=headers)
    assert resp.status_code == 404
    assert_matches_contract(contract, "/v1/diary/days/{date}", "get", 404, resp.json())


async def test_get_day_400(client, user, contract):
    _, headers = user
    resp = await client.get(f"/v1/diary/days/{TODAY.isoformat()}", headers=headers)
    assert resp.status_code == 400
    assert_matches_contract(contract, "/v1/diary/days/{date}", "get", 400, resp.json())


async def test_post_201_y_400_y_404(client, user, make_food, contract):
    _, headers = user
    food = await make_food("Pan", kcal=200)
    body = {"date": TODAY.isoformat(), "meal": "lunch", "food_id": str(food), "quantity": 100}
    ok = await client.post("/v1/diary/entries?utc_offset_min=0", json=body, headers=headers)
    assert ok.status_code == 201
    assert_matches_contract(contract, "/v1/diary/entries", "post", 201, ok.json())
    bad = await client.post(
        "/v1/diary/entries?utc_offset_min=0", json={**body, "quantity": 0}, headers=headers
    )
    assert bad.status_code == 400
    assert_matches_contract(contract, "/v1/diary/entries", "post", 400, bad.json())
    body["food_id"] = "00000000-0000-4000-8000-000000000000"
    missing = await client.post("/v1/diary/entries?utc_offset_min=0", json=body, headers=headers)
    assert missing.status_code == 404
    assert_matches_contract(contract, "/v1/diary/entries", "post", 404, missing.json())


async def test_patch_delete_restore(client, user, make_entry, contract):
    account, headers = user
    entry = await make_entry(account, TODAY, "lunch", kcal=250, quantity=100)
    path = f"/v1/diary/entries/{entry}"
    q = "?utc_offset_min=0"
    spec = "/v1/diary/entries/{entry_id}"

    patched = await client.patch(path + q, json={"quantity": 150}, headers=headers)
    assert patched.status_code == 200
    assert_matches_contract(contract, spec, "patch", 200, patched.json())

    deleted = await client.delete(path + q, headers=headers)
    assert deleted.status_code == 200
    assert_matches_contract(contract, spec, "delete", 200, deleted.json())

    restored = await client.post(path + "/restore" + q, headers=headers)
    assert restored.status_code == 200
    assert_matches_contract(contract, spec + "/restore", "post", 200, restored.json())

    again = await client.post(path + "/restore" + q, headers=headers)
    assert again.status_code == 404
    assert_matches_contract(contract, spec + "/restore", "post", 404, again.json())
    missing = await client.patch(
        "/v1/diary/entries/00000000-0000-4000-8000-000000000000" + q,
        json={"quantity": 1},
        headers=headers,
    )
    assert missing.status_code == 404
    assert_matches_contract(contract, spec, "patch", 404, missing.json())
