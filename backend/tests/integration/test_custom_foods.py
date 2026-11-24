"""US3: crear, buscar, editar y eliminar alimentos personalizados."""

import json
import uuid
from pathlib import Path

import httpx
import pytest

BARCODE = "8410000000016"


def payload(**over):
    body = {
        "name": "Tarta de la abuela",
        "base_unit": "g",
        "basis": "per_100",
        "values": {"kcal": 320, "protein_g": 6, "carbs_g": 45, "fat_g": 13},
    }
    body.update(over)
    return body


async def create(client, headers, **over):
    return await client.post("/v1/foods/custom", json=payload(**over), headers=headers)


async def test_crear_con_los_cuatro_obligatorios(client, user_with_consent):
    _, headers = await user_with_consent("a")
    resp = await create(client, headers)
    assert resp.status_code == 201
    body = resp.json()
    assert body["warnings"] == []
    food = body["food"]
    assert (food["kind"], food["source"], food["is_mine"]) == ("custom", "user", True)
    assert food["per_100"]["kcal"] == 320
    assert food["per_100"]["fiber_g"] is None


async def test_por_racion_guarda_por_100_y_la_racion(client, user_with_consent):
    _, headers = await user_with_consent("a")
    resp = await create(
        client,
        headers,
        basis="per_serving",
        serving_size=150,
        values={"kcal": 480, "protein_g": 9, "carbs_g": 60, "fat_g": 15},
    )
    food = resp.json()["food"]
    assert food["per_100"]["kcal"] == 320
    assert food["per_100"]["protein_g"] == 6
    assert food["serving_size"] == 150


async def test_aparece_en_la_busqueda_antes_que_un_generico(client, user_with_consent, make_food):
    _, headers = await user_with_consent("a")
    await make_food("Tarta de manzana")
    await create(client, headers, name="Tarta de manzana")
    items = (
        await client.get("/v1/foods/search", params={"q": "tarta manzana"}, headers=headers)
    ).json()["items"]
    assert [i["kind"] for i in items[:2]] == ["custom", "generic"]
    assert items[0]["is_mine"] is True
    assert items[1]["is_mine"] is False


async def test_lista_por_nombre(client, user_with_consent):
    _, headers = await user_with_consent("a")
    for name in ("zanahoria", "Bizcocho", "arroz"):
        await create(client, headers, name=name)
    items = (await client.get("/v1/foods/custom", headers=headers)).json()["items"]
    assert [i["name"] for i in items] == ["arroz", "Bizcocho", "zanahoria"]


async def test_editar_cambia_lo_mostrado(client, user_with_consent):
    _, headers = await user_with_consent("a")
    food_id = (await create(client, headers)).json()["food"]["id"]
    resp = await client.put(
        f"/v1/foods/custom/{food_id}",
        json=payload(
            name="Tarta nueva", values={"kcal": 300, "protein_g": 5, "carbs_g": 40, "fat_g": 12}
        ),
        headers=headers,
    )
    assert resp.status_code == 200
    detail = (await client.get(f"/v1/foods/{food_id}", headers=headers)).json()
    assert (detail["name"], detail["per_100"]["kcal"]) == ("Tarta nueva", 300)
    found = (await client.get("/v1/foods/search", params={"q": "nueva"}, headers=headers)).json()[
        "items"
    ]
    assert [i["name"] for i in found] == ["Tarta nueva"]
    gone = (await client.get("/v1/foods/search", params={"q": "abuela"}, headers=headers)).json()[
        "items"
    ]
    assert gone == []


async def test_eliminar_es_logico_y_desaparece_de_todo(client, user_with_consent, app):
    from sqlalchemy import text

    _, headers = await user_with_consent("a")
    food_id = (await create(client, headers, barcode=BARCODE)).json()["food"]["id"]
    assert (await client.delete(f"/v1/foods/custom/{food_id}", headers=headers)).status_code == 204
    assert (await client.get(f"/v1/foods/{food_id}", headers=headers)).status_code == 404
    assert (await client.get("/v1/foods/custom", headers=headers)).json()["items"] == []
    assert (await client.get("/v1/foods/search", params={"q": "abuela"}, headers=headers)).json()[
        "items"
    ] == []
    async with app.state.sessionmaker() as s:
        row = (
            await s.execute(text("SELECT deleted_at FROM food WHERE id = :i"), {"i": food_id})
        ).one()
    assert row[0] is not None  # la fila sigue existiendo (FR-015)
    again = await client.delete(f"/v1/foods/custom/{food_id}", headers=headers)
    assert again.status_code == 404


async def test_codigo_repetido_es_409_y_se_puede_reutilizar_tras_eliminar(
    client, user_with_consent
):
    _, headers = await user_with_consent("a")
    first = (await create(client, headers, barcode=BARCODE)).json()["food"]["id"]
    dup = await create(client, headers, name="Otra", barcode=BARCODE)
    assert dup.status_code == 409
    assert dup.json()["code"] == "FOOD_BARCODE_TAKEN"
    other = (await create(client, headers, name="Otra", barcode="8410000000023")).json()["food"]
    clash = await client.put(
        f"/v1/foods/custom/{other['id']}",
        json=payload(name="Otra", barcode=BARCODE),
        headers=headers,
    )
    assert clash.status_code == 409
    # Editar sin cambiar su propio código no choca consigo mismo.
    same = await client.put(
        f"/v1/foods/custom/{first}", json=payload(barcode=BARCODE), headers=headers
    )
    assert same.status_code == 200
    await client.delete(f"/v1/foods/custom/{first}", headers=headers)
    reuse = await create(client, headers, name="Reutiliza", barcode=BARCODE)
    assert reuse.status_code == 201


async def test_el_personalizado_gana_a_open_food_facts_por_codigo(client, user_with_consent, app):
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        fixture = Path(__file__).parent.parent / "fixtures" / "off" / "found_grams.json"
        return httpx.Response(200, json=json.loads(fixture.read_text("utf-8")))

    app.state.off_transport = httpx.MockTransport(handler)
    try:
        _, headers = await user_with_consent("a")
        await create(client, headers, name="Mi yogur", barcode=BARCODE)
        body = (
            await client.get("/v1/foods/barcode", params={"code": BARCODE}, headers=headers)
        ).json()
        assert body["food"]["name"] == "Mi yogur"
        assert calls == []
    finally:
        app.state.off_transport = None


async def test_kcal_mismatch_avisa_y_guarda(client, user_with_consent):
    _, headers = await user_with_consent("a")
    resp = await create(
        client, headers, values={"kcal": 100, "protein_g": 10, "carbs_g": 10, "fat_g": 10}
    )
    assert resp.status_code == 201
    assert resp.json()["warnings"] == ["KCAL_MISMATCH"]
    assert len((await client.get("/v1/foods/custom", headers=headers)).json()["items"]) == 1


@pytest.mark.parametrize(
    ("over", "fields"),
    [
        (
            {"values": {"kcal": 100, "protein_g": 50, "carbs_g": 40, "fat_g": 20}},
            ["protein_g", "carbs_g", "fat_g", "fiber_g"],
        ),
        ({"values": {"kcal": -1, "protein_g": 1, "carbs_g": 1, "fat_g": 1}}, ["kcal"]),
        ({"values": {"kcal": 1000, "protein_g": 1, "carbs_g": 1, "fat_g": 1}}, ["kcal"]),
        ({"basis": "per_serving"}, ["serving_size"]),
        ({"name": "   "}, ["name"]),
        ({"barcode": "8410000000017"}, ["barcode"]),
    ],
)
async def test_errores_con_los_nombres_de_campo_y_nunca_valores(
    client, user_with_consent, over, fields
):
    _, headers = await user_with_consent("a")
    resp = await create(client, headers, **over)
    assert resp.status_code == 400
    body = resp.json()
    assert body["code"] == "VALIDATION_ERROR"
    assert body["fields"] == fields
    assert "50" not in json.dumps(body)
    assert (await client.get("/v1/foods/custom", headers=headers)).json()["items"] == []


async def test_editar_o_eliminar_no_cambia_lo_ya_copiado(client, user_with_consent, app):
    """FR-015: lo que se copió a otra fila no cambia al editar el alimento original."""
    from sqlalchemy import text

    _, headers = await user_with_consent("a")
    food = (await create(client, headers)).json()["food"]
    copied = dict(food["per_100"])  # lo que guardará el diario (004) en su propia fila
    await client.put(
        f"/v1/foods/custom/{food['id']}",
        json=payload(values={"kcal": 10, "protein_g": 1, "carbs_g": 1, "fat_g": 1}),
        headers=headers,
    )
    await client.delete(f"/v1/foods/custom/{food['id']}", headers=headers)
    assert copied["kcal"] == 320
    async with app.state.sessionmaker() as s:
        kcal = (
            await s.execute(text("SELECT kcal FROM food WHERE id = :i"), {"i": food["id"]})
        ).scalar_one()
    assert kcal == 10  # la fila original sí cambió; la copia no depende de ella


async def test_id_inexistente_en_put_es_404(client, user_with_consent):
    _, headers = await user_with_consent("a")
    resp = await client.put(f"/v1/foods/custom/{uuid.uuid4()}", json=payload(), headers=headers)
    assert resp.status_code == 404
    assert resp.json()["code"] == "FOOD_NOT_FOUND"
