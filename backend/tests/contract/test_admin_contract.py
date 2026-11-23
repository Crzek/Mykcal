from tests.contract.schema import assert_matches_contract

G, R = "/v1/admin/invitation", "/v1/admin/invitation/rotate"


async def test_get_y_rotate_200(client, zitadel, seed_code, contract):
    await seed_code()
    get = await client.get(G, headers=zitadel.headers("admin-sub"))
    assert_matches_contract(contract, G, "get", 200, get.json())
    rot = await client.post(R, headers=zitadel.headers("admin-sub"))
    assert_matches_contract(contract, R, "post", 200, rot.json())


async def test_401_y_403(client, zitadel, make_account, contract):
    await make_account("u1")
    for path, method in [(G, "get"), (R, "post")]:
        r401 = await client.request(method, path)
        assert_matches_contract(contract, path, method, 401, r401.json())
        r403 = await client.request(method, path, headers=zitadel.headers("u1"))
        assert_matches_contract(contract, path, method, 403, r403.json())
