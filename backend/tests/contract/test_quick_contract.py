"""T017/T036/T051 (005): las respuestas de recientes, favoritos y copia validan contra 0.5.0."""

from datetime import UTC, datetime, timedelta

import pytest

from tests.contract.schema import assert_matches_contract

NOW = datetime.now(UTC)
TODAY = NOW.date()


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("quick-contract")
    await make_target_version(account, NOW - timedelta(days=30))
    return account, headers


async def test_recent_200_y_no_cae_en_food_id(client, user, make_entry, contract):
    account, headers = user
    await make_entry(account, TODAY, name="Pan")
    resp = await client.get("/v1/foods/recent", headers=headers)
    assert resp.status_code == 200  # no 422: /v1/foods/{food_id} no lo captura (R10)
    assert_matches_contract(contract, "/v1/foods/recent", "get", 200, resp.json())
    assert len(resp.json()["items"]) == 1


async def test_favorites_get_put_delete(client, user, make_food, contract):
    _, headers = user
    food = await make_food("Plátano")
    assert (await client.put(f"/v1/foods/favorites/{food}", headers=headers)).status_code == 204
    resp = await client.get("/v1/foods/favorites", headers=headers)
    assert resp.status_code == 200
    assert_matches_contract(contract, "/v1/foods/favorites", "get", 200, resp.json())
    assert resp.json()["items"][0]["is_favorite"] is True
    assert (await client.delete(f"/v1/foods/favorites/{food}", headers=headers)).status_code == 204
    missing = await client.put(
        "/v1/foods/favorites/00000000-0000-4000-8000-000000000000", headers=headers
    )
    assert missing.status_code == 404
    assert_matches_contract(contract, "/v1/foods/favorites/{food_id}", "put", 404, missing.json())


async def test_copy_sources_copies_y_undo(client, user, make_entry, contract):
    account, headers = user
    await make_entry(account, TODAY - timedelta(days=1), "breakfast", name="Pan")
    params = {"target_date": TODAY.isoformat(), "target_meal": "breakfast"}
    sources = await client.get("/v1/diary/copy-sources", params=params, headers=headers)
    assert sources.status_code == 200
    assert_matches_contract(contract, "/v1/diary/copy-sources", "get", 200, sources.json())
    body = {
        "source_date": (TODAY - timedelta(days=1)).isoformat(),
        "source_meal": "breakfast",
        "target_date": TODAY.isoformat(),
        "target_meal": "breakfast",
    }
    done = await client.post("/v1/diary/copies?utc_offset_min=0", json=body, headers=headers)
    assert done.status_code == 201
    assert_matches_contract(contract, "/v1/diary/copies", "post", 201, done.json())
    empty = await client.post(
        "/v1/diary/copies?utc_offset_min=0", json={**body, "source_meal": "dinner"}, headers=headers
    )
    assert empty.status_code == 400
    assert_matches_contract(contract, "/v1/diary/copies", "post", 400, empty.json())
    undone = await client.delete(
        f"/v1/diary/copies/{done.json()['copy_id']}?utc_offset_min=0", headers=headers
    )
    assert undone.status_code == 200
    assert_matches_contract(contract, "/v1/diary/copies/{copy_id}", "delete", 200, undone.json())
    again = await client.delete(
        f"/v1/diary/copies/{done.json()['copy_id']}?utc_offset_min=0", headers=headers
    )
    assert again.status_code == 404
    assert_matches_contract(contract, "/v1/diary/copies/{copy_id}", "delete", 404, again.json())
