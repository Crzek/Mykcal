"""T037 (004): la entrada conserva el nombre y los valores del alimento (FR-004, SC-004)."""

from datetime import UTC, datetime, timedelta

import pytest

TODAY = datetime.now(UTC).date()


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("diary-snapshot")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=30))
    return account, headers


CUSTOM = {
    "name": "Tarta de la abuela",
    "base_unit": "g",
    "basis": "per_100",
    "values": {"kcal": 320, "protein_g": 6, "carbs_g": 45, "fat_g": 13, "fiber_g": 2},
}


async def day(client, headers):
    resp = await client.get(f"/v1/diary/days/{TODAY.isoformat()}?utc_offset_min=0", headers=headers)
    return resp.json()


async def test_editar_y_eliminar_el_personalizado_no_cambia_la_entrada(client, user):
    _, headers = user
    created = await client.post("/v1/foods/custom", json=CUSTOM, headers=headers)
    food_id = created.json()["food"]["id"]
    added = await client.post(
        "/v1/diary/entries?utc_offset_min=0",
        json={"date": TODAY.isoformat(), "meal": "dinner", "food_id": food_id, "quantity": 200},
        headers=headers,
    )
    before = added.json()
    entry_before = next(m for m in before["meals"] if m["meal"] == "dinner")["entries"][0]
    assert entry_before["values"]["kcal"] == 640

    changed = {**CUSTOM, "name": "Otra tarta", "values": {**CUSTOM["values"], "kcal": 100}}
    assert (
        await client.put(f"/v1/foods/custom/{food_id}", json=changed, headers=headers)
    ).status_code == 200
    after_edit = await day(client, headers)
    assert after_edit == before

    assert (await client.delete(f"/v1/foods/custom/{food_id}", headers=headers)).status_code == 204
    after_delete = await day(client, headers)
    assert after_delete == before
    entry = next(m for m in after_delete["meals"] if m["meal"] == "dinner")["entries"][0]
    assert entry["food_name"] == "Tarta de la abuela"
    assert entry["per_100"]["kcal"] == 320
    assert after_delete["totals"]["consumed"]["kcal"] == 640


async def test_registrar_despues_de_editar_usa_los_valores_nuevos(client, user):
    """La copia se hace al registrar: una entrada nueva ve el alimento ya editado."""
    _, headers = user
    created = await client.post("/v1/foods/custom", json=CUSTOM, headers=headers)
    food_id = created.json()["food"]["id"]
    changed = {**CUSTOM, "values": {**CUSTOM["values"], "kcal": 100}}
    await client.put(f"/v1/foods/custom/{food_id}", json=changed, headers=headers)
    resp = await client.post(
        "/v1/diary/entries?utc_offset_min=0",
        json={"date": TODAY.isoformat(), "meal": "lunch", "food_id": food_id, "quantity": 100},
        headers=headers,
    )
    entry = next(m for m in resp.json()["meals"] if m["meal"] == "lunch")["entries"][0]
    assert entry["values"]["kcal"] == 100
