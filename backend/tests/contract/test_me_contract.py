from tests.contract.schema import assert_matches_contract


async def test_health(client, contract):
    resp = await client.get("/v1/health")
    assert resp.status_code == 200
    assert_matches_contract(contract, "/v1/health", "get", 200, resp.json())


async def test_me_200(client, zitadel, make_account, contract):
    await make_account("u1", name="Ana")
    resp = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert resp.status_code == 200
    assert_matches_contract(contract, "/v1/me", "get", 200, resp.json())
    body = resp.json()
    assert (
        body["display_name"] == "Ana" and body["is_admin"] is False and body["status"] == "active"
    )


async def test_me_admin(client, zitadel, make_account):
    await make_account("admin-sub")
    resp = await client.get("/v1/me", headers=zitadel.headers("admin-sub"))
    assert resp.json()["is_admin"] is True


async def test_me_401_y_404(client, zitadel, contract):
    r401 = await client.get("/v1/me")
    assert r401.status_code == 401
    assert_matches_contract(contract, "/v1/me", "get", 401, r401.json())
    r404 = await client.get("/v1/me", headers=zitadel.headers("nadie"))
    assert_matches_contract(contract, "/v1/me", "get", 404, r404.json())


async def test_me_503(client, zitadel, contract):
    zitadel.jwks_down = True
    resp = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert_matches_contract(contract, "/v1/me", "get", 503, resp.json())
