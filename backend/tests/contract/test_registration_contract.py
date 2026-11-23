from tests.contract.schema import assert_matches_contract

P = "/v1/registration"


async def post(client, zitadel, sub, code):
    return await client.post(P, headers=zitadel.headers(sub), json={"invitation_code": code})


async def test_201(client, zitadel, seed_code, contract):
    code = await seed_code()
    resp = await post(client, zitadel, "u1", code)
    assert resp.status_code == 201
    assert_matches_contract(contract, P, "post", 201, resp.json())


async def test_400_401_409(client, zitadel, seed_code, contract):
    code = await seed_code()
    r400 = await post(client, zitadel, "u1", "ZZZZ9999")
    assert_matches_contract(contract, P, "post", 400, r400.json())
    r401 = await client.post(P, json={"invitation_code": code})
    assert_matches_contract(contract, P, "post", 401, r401.json())
    await post(client, zitadel, "u2", code)
    r409 = await post(client, zitadel, "u2", code)
    assert_matches_contract(contract, P, "post", 409, r409.json())


async def test_429_con_retry_after(client, zitadel, seed_code, contract):
    await seed_code()
    for _ in range(4):
        await post(client, zitadel, "u1", "ZZZZ9999")
    resp = await post(client, zitadel, "u1", "ZZZZ9999")
    assert resp.status_code == 429 and int(resp.headers["retry-after"]) >= 1
    assert_matches_contract(contract, P, "post", 429, resp.json())
