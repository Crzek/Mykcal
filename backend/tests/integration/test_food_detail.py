"""Detalle de un alimento (US1.2, FR-003, FR-016)."""

import uuid
from decimal import Decimal


async def test_generico_con_sin_dato_y_con_cero(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    food_id = await make_food(
        "Plátano, crudo",
        kcal=Decimal("90.5"),
        protein_g=Decimal("1.1"),
        carbs_g=Decimal("19.7"),
        fat_g=Decimal("0.3"),
        fiber_g=Decimal("2"),
        sodium_mg=Decimal("0"),  # un 0 explícito no es «sin dato»
        potassium_mg=Decimal("358"),
        vitamin_c_mg=Decimal("8.7"),
    )
    resp = await client.get(f"/v1/foods/{food_id}", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["kind"] == "generic"
    assert body["source"] == "ciqual"
    assert body["base_unit"] == "g"
    assert body["is_mine"] is False
    assert body["serving_size"] is None
    per100 = body["per_100"]
    assert per100["kcal"] == 90.5
    assert per100["sodium_mg"] == 0  # cero
    assert per100["vitamin_d_ug"] is None  # sin dato
    assert per100["calcium_mg"] is None
    assert len(per100) == 12


async def test_envasado_con_racion_y_unidad_ml(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    food_id = await make_food(
        "Zumo de naranja",
        kind="packaged",
        barcode="8410000000009",
        brand="Marca",
        base_unit="ml",
        serving_size=Decimal("200"),
    )
    body = (await client.get(f"/v1/foods/{food_id}", headers=headers)).json()
    assert body["kind"] == "packaged"
    assert body["source"] == "off"
    assert body["base_unit"] == "ml"
    assert body["brand"] == "Marca"
    assert body["barcode"] == "8410000000009"
    assert body["serving_size"] == 200


async def test_propio_lleva_is_mine(client, user_with_consent, make_food):
    me, headers = await user_with_consent("u1")
    food_id = await make_food("Tarta", kind="custom", owner=me)
    body = (await client.get(f"/v1/foods/{food_id}", headers=headers)).json()
    assert body["is_mine"] is True
    assert body["source"] == "user"


async def test_inexistente_archivado_o_id_no_uuid(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    resp = await client.get(f"/v1/foods/{uuid.uuid4()}", headers=headers)
    assert resp.status_code == 404
    assert resp.json()["code"] == "FOOD_NOT_FOUND"
    bad = await client.get("/v1/foods/no-es-un-uuid", headers=headers)
    assert bad.status_code == 400
    assert bad.json()["code"] == "VALIDATION_ERROR"


async def test_sin_consentimiento_no_hay_detalle(client, make_account, zitadel, make_food):
    await make_account("sin-consentimiento")
    food_id = await make_food("Plátano, crudo")
    resp = await client.get(f"/v1/foods/{food_id}", headers=zitadel.headers("sin-consentimiento"))
    assert resp.status_code == 403
    assert resp.json()["code"] == "CONSENT_REQUIRED"
