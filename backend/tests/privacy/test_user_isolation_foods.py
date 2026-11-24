"""SC-004: el usuario B nunca ve un personalizado de A, por ninguna vía."""

import uuid

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]

BARCODE = "8410000000016"


def body(**over):
    data = {
        "name": "Receta secreta de A",
        "barcode": BARCODE,
        "base_unit": "g",
        "basis": "per_100",
        "values": {"kcal": 200, "protein_g": 10, "carbs_g": 20, "fat_g": 8},
    }
    data.update(over)
    return data


async def test_b_no_ve_el_personalizado_de_a(client, user_with_consent):
    _, ha = await user_with_consent("a")
    _, hb = await user_with_consent("b")
    created = await client.post("/v1/foods/custom", json=body(), headers=ha)
    food_id = created.json()["food"]["id"]

    search = await client.get("/v1/foods/search", params={"q": "receta secreta"}, headers=hb)
    assert search.json()["items"] == []
    assert (await client.get("/v1/foods/custom", headers=hb)).json()["items"] == []
    detail = await client.get(f"/v1/foods/{food_id}", headers=hb)
    missing = await client.get(f"/v1/foods/{uuid.uuid4()}", headers=hb)
    assert detail.status_code == missing.status_code == 404
    assert detail.json() == missing.json()  # indistinguible de un id inexistente


async def test_b_no_lo_ve_por_codigo_de_barras(client, user_with_consent, app):
    import httpx

    app.state.off_transport = httpx.MockTransport(
        lambda request: httpx.Response(200, json={"status": 0, "code": BARCODE})
    )
    try:
        _, ha = await user_with_consent("a")
        _, hb = await user_with_consent("b")
        await client.post("/v1/foods/custom", json=body(), headers=ha)
        resp = await client.get("/v1/foods/barcode", params={"code": BARCODE}, headers=hb)
        assert resp.json() == {"result": "not_found", "code": BARCODE}
    finally:
        app.state.off_transport = None


async def test_b_no_puede_editar_ni_eliminar_el_de_a(client, user_with_consent):
    _, ha = await user_with_consent("a")
    _, hb = await user_with_consent("b")
    food_id = (await client.post("/v1/foods/custom", json=body(), headers=ha)).json()["food"]["id"]
    inexistente = uuid.uuid4()

    put = await client.put(f"/v1/foods/custom/{food_id}", json=body(name="Robado"), headers=hb)
    put_missing = await client.put(
        f"/v1/foods/custom/{inexistente}", json=body(name="Robado"), headers=hb
    )
    delete = await client.delete(f"/v1/foods/custom/{food_id}", headers=hb)
    delete_missing = await client.delete(f"/v1/foods/custom/{inexistente}", headers=hb)
    assert put.status_code == delete.status_code == 404
    assert put.json() == put_missing.json()
    assert delete.json() == delete_missing.json()

    # Sigue intacto para A.
    detail = (await client.get(f"/v1/foods/{food_id}", headers=ha)).json()
    assert detail["name"] == "Receta secreta de A"


async def test_b_puede_crear_el_mismo_nombre_y_codigo_sin_conflicto(client, user_with_consent):
    _, ha = await user_with_consent("a")
    _, hb = await user_with_consent("b")
    assert (await client.post("/v1/foods/custom", json=body(), headers=ha)).status_code == 201
    assert (await client.post("/v1/foods/custom", json=body(), headers=hb)).status_code == 201
    mine_a = (await client.get("/v1/foods/custom", headers=ha)).json()["items"]
    mine_b = (await client.get("/v1/foods/custom", headers=hb)).json()["items"]
    assert len(mine_a) == len(mine_b) == 1
    assert mine_a[0]["id"] != mine_b[0]["id"]
