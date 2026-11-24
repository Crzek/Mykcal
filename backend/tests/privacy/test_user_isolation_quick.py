"""SC-004 / principio V (005): B nunca ve ni toca recientes, favoritos o copias de A."""

import uuid
from datetime import UTC, datetime, timedelta

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]

NOW = datetime.now(UTC)
TODAY = NOW.date()


@pytest.fixture
async def two_users(user_with_consent, make_target_version):
    a, ha = await user_with_consent("quick-a")
    b, hb = await user_with_consent("quick-b")
    for account in (a, b):
        await make_target_version(account, NOW - timedelta(days=30))
    return (a, ha), (b, hb)


def without_request_id(body: dict) -> dict:
    return {k: v for k, v in body.items() if k != "request_id"}


async def test_b_no_ve_en_recientes_lo_que_solo_registro_a(
    client, two_users, make_entry, make_food, make_favorite
):
    (a, ha), (b, hb) = two_users
    tarta = await make_food("Tarta secreta de A", kind="custom", owner=a)
    pan = await make_food("Pan común")
    await make_entry(a, TODAY, food_id=tarta)
    await make_entry(a, TODAY, food_id=pan)
    await make_favorite(a, pan)
    await make_entry(b, TODAY, food_id=pan, quantity=40)
    resp = await client.get("/v1/foods/recent", headers=hb)
    assert resp.status_code == 200
    assert "Tarta secreta de A" not in resp.text
    items = resp.json()["items"]
    assert [i["food"]["name"] for i in items] == ["Pan común"]
    # Ni la cantidad ni el favorito de A se filtran a B
    assert items[0]["suggested_quantity"] == 40 and items[0]["is_favorite"] is False
    # Y A sigue viendo lo suyo
    mine = (await client.get("/v1/foods/recent", headers=ha)).json()["items"]
    assert {i["food"]["name"] for i in mine} == {"Tarta secreta de A", "Pan común"}


async def test_b_no_ve_ni_toca_los_favoritos_de_a(client, two_users, make_food, make_favorite):
    (a, ha), (_, hb) = two_users
    pan = await make_food("Pan común")
    ajeno = await make_food("Tarta de A", kind="custom", owner=a)
    await make_favorite(a, pan)
    await make_favorite(a, ajeno)
    assert (await client.get("/v1/foods/favorites", headers=hb)).json()["items"] == []
    # B no puede marcar un personalizado de A: mismo 404 que un id inexistente
    theirs = await client.put(f"/v1/foods/favorites/{ajeno}", headers=hb)
    nobody = await client.put(f"/v1/foods/favorites/{uuid.uuid4()}", headers=hb)
    assert theirs.status_code == nobody.status_code == 404
    assert theirs.json()["code"] == "FOOD_NOT_FOUND"
    assert without_request_id(theirs.json()) == without_request_id(nobody.json())
    # El DELETE de B no quita el favorito de A
    assert (await client.delete(f"/v1/foods/favorites/{pan}", headers=hb)).status_code == 204
    names = {
        i["food"]["name"]
        for i in (await client.get("/v1/foods/favorites", headers=ha)).json()["items"]
    }
    assert names == {"Pan común", "Tarta de A"}


def _copy_body(day=TODAY - timedelta(days=1), meal="breakfast"):
    return {
        "source_date": day.isoformat(),
        "source_meal": meal,
        "target_date": TODAY.isoformat(),
        "target_meal": meal,
    }


async def test_b_no_ve_comidas_de_a_para_copiar(client, two_users, make_entry):
    (a, _), (b, hb) = two_users
    await make_entry(a, TODAY - timedelta(days=1), "breakfast", name="Desayuno secreto de A")
    resp = await client.get(
        "/v1/diary/copy-sources",
        params={"target_date": TODAY.isoformat(), "target_meal": "breakfast"},
        headers=hb,
    )
    assert resp.status_code == 200
    assert resp.json() == {"days": []} and "secreto" not in resp.text


async def test_b_no_puede_copiar_una_comida_de_a(app, client, two_users, make_entry):
    (a, ha), (b, hb) = two_users
    await make_entry(a, TODAY - timedelta(days=1), "breakfast", name="Desayuno secreto de A")
    resp = await client.post("/v1/diary/copies?utc_offset_min=0", json=_copy_body(), headers=hb)
    assert resp.status_code == 400 and resp.json()["code"] == "COPY_SOURCE_EMPTY"
    assert "secreto" not in resp.text
    day = (
        await client.get(f"/v1/diary/days/{TODAY.isoformat()}?utc_offset_min=0", headers=hb)
    ).json()
    assert all(m["entries"] == [] for m in day["meals"])


async def test_b_no_puede_deshacer_una_copia_de_a(client, two_users, make_entry):
    (a, ha), (_, hb) = two_users
    await make_entry(a, TODAY - timedelta(days=1), "breakfast", name="Desayuno de A")
    copy_id = (
        await client.post("/v1/diary/copies?utc_offset_min=0", json=_copy_body(), headers=ha)
    ).json()["copy_id"]
    theirs = await client.delete(f"/v1/diary/copies/{copy_id}?utc_offset_min=0", headers=hb)
    nobody = await client.delete(f"/v1/diary/copies/{uuid.uuid4()}?utc_offset_min=0", headers=hb)
    assert theirs.status_code == nobody.status_code == 404
    assert theirs.json()["code"] == "COPY_NOT_FOUND"
    assert without_request_id(theirs.json()) == without_request_id(nobody.json())
    # Las entradas de A siguen activas
    day = (
        await client.get(f"/v1/diary/days/{TODAY.isoformat()}?utc_offset_min=0", headers=ha)
    ).json()
    assert len(next(m for m in day["meals"] if m["meal"] == "breakfast")["entries"]) == 1
