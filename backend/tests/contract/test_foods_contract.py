"""Respuestas de las rutas de 003 validadas contra el contrato vivo (openapi.yaml)."""

import uuid

from tests.contract.schema import assert_matches_contract


async def test_search_y_detalle(client, user_with_consent, make_food, contract):
    me, headers = await user_with_consent("u1")
    generic = await make_food("Plátano, crudo", fiber_g=2, serving_size=None)
    await make_food("Plátano frito", kind="custom", owner=me)

    resp = await client.get("/v1/foods/search", params={"q": "platano"}, headers=headers)
    assert resp.status_code == 200
    assert_matches_contract(contract, "/v1/foods/search", "get", 200, resp.json())
    assert len(resp.json()["items"]) == 2

    short = await client.get("/v1/foods/search", params={"q": "p"}, headers=headers)
    assert_matches_contract(contract, "/v1/foods/search", "get", 400, short.json())

    detail = await client.get(f"/v1/foods/{generic}", headers=headers)
    assert detail.status_code == 200
    assert_matches_contract(contract, "/v1/foods/{food_id}", "get", 200, detail.json())

    missing = await client.get(f"/v1/foods/{uuid.uuid4()}", headers=headers)
    assert missing.status_code == 404
    assert_matches_contract(contract, "/v1/foods/{food_id}", "get", 404, missing.json())


async def test_barcode_contrato(client, user_with_consent, app, contract):
    import json
    from pathlib import Path

    import httpx

    fixtures = Path(__file__).parent.parent / "fixtures" / "off"
    codes = {
        "8410000000016": "found_grams",
        "8410000000047": "no_macros",
        "8410000000054": "not_found",
    }
    mode = {"fail": False}

    def handler(request: httpx.Request) -> httpx.Response:
        if mode["fail"]:
            return httpx.Response(503)
        name = codes[request.url.path.rsplit("/", 1)[-1]]
        return httpx.Response(200, json=json.loads((fixtures / f"{name}.json").read_text("utf-8")))

    app.state.off_transport = httpx.MockTransport(handler)
    try:
        _, headers = await user_with_consent("u1")
        path = "/v1/foods/barcode"
        for code, result in (
            ("8410000000016", "found"),
            ("8410000000054", "not_found"),
            ("8410000000047", "incomplete"),
        ):
            resp = await client.get(path, params={"code": code}, headers=headers)
            assert resp.status_code == 200
            assert resp.json()["result"] == result
            assert_matches_contract(contract, path, "get", 200, resp.json())
        bad = await client.get(path, params={"code": "123"}, headers=headers)
        assert_matches_contract(contract, path, "get", 400, bad.json())
        mode["fail"] = True
        down = await client.get(path, params={"code": "8410000000061"}, headers=headers)
        assert down.status_code == 503
        assert_matches_contract(contract, path, "get", 503, down.json())
    finally:
        app.state.off_transport = None


async def test_custom_contrato(client, user_with_consent, contract):
    _, headers = await user_with_consent("u1")
    body = {
        "name": "Tarta",
        "base_unit": "g",
        "basis": "per_100",
        "values": {"kcal": 320, "protein_g": 6, "carbs_g": 45, "fat_g": 13},
    }
    created = await client.post("/v1/foods/custom", json=body, headers=headers)
    assert created.status_code == 201
    assert_matches_contract(contract, "/v1/foods/custom", "post", 201, created.json())
    food_id = created.json()["food"]["id"]

    listing = await client.get("/v1/foods/custom", headers=headers)
    assert_matches_contract(contract, "/v1/foods/custom", "get", 200, listing.json())

    bad = await client.post("/v1/foods/custom", json={**body, "name": ""}, headers=headers)
    assert bad.status_code == 400
    assert_matches_contract(contract, "/v1/foods/custom", "post", 400, bad.json())

    with_code = {**body, "name": "Con código", "barcode": "8410000000016"}
    assert (
        await client.post("/v1/foods/custom", json=with_code, headers=headers)
    ).status_code == 201
    taken = await client.post("/v1/foods/custom", json=with_code, headers=headers)
    assert taken.status_code == 409
    assert_matches_contract(contract, "/v1/foods/custom", "post", 409, taken.json())

    path = "/v1/foods/custom/{food_id}"
    updated = await client.put(f"/v1/foods/custom/{food_id}", json=body, headers=headers)
    assert_matches_contract(contract, path, "put", 200, updated.json())
    missing = await client.put(f"/v1/foods/custom/{uuid.uuid4()}", json=body, headers=headers)
    assert_matches_contract(contract, path, "put", 404, missing.json())

    deleted = await client.delete(f"/v1/foods/custom/{food_id}", headers=headers)
    assert deleted.status_code == 204
    gone = await client.delete(f"/v1/foods/custom/{food_id}", headers=headers)
    assert_matches_contract(contract, path, "delete", 404, gone.json())
