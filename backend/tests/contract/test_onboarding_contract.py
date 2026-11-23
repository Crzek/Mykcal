"""Respuestas de las rutas de 002 validadas contra el contrato vivo (openapi.yaml)."""

from mykcal.consent.service import CURRENT_CONSENT_VERSION
from tests.contract.schema import assert_matches_contract


async def test_consent(client, zitadel, make_account, contract):
    await make_account("u1")
    resp = await client.post(
        "/v1/consent", json={"text_version": CURRENT_CONSENT_VERSION}, headers=zitadel.headers("u1")
    )
    assert_matches_contract(contract, "/v1/consent", "post", 201, resp.json())
    bad = await client.post(
        "/v1/consent", json={"text_version": "x"}, headers=zitadel.headers("u1")
    )
    assert_matches_contract(contract, "/v1/consent", "post", 409, bad.json())


async def test_profile_get_y_put(
    client, zitadel, make_account, grant_consent, profile_body, contract
):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    r404 = await client.get("/v1/profile", headers=h)
    assert_matches_contract(contract, "/v1/profile", "get", 404, r404.json())
    put = await client.put("/v1/profile", json=profile_body(), headers=h)
    assert_matches_contract(contract, "/v1/profile", "put", 200, put.json())
    got = await client.get("/v1/profile", headers=h)
    assert_matches_contract(contract, "/v1/profile", "get", 200, got.json())
    bad = await client.put("/v1/profile", json=profile_body(age=1), headers=h)
    assert_matches_contract(contract, "/v1/profile", "put", 400, bad.json())


async def test_me_incluye_onboarding(client, zitadel, make_account, contract):
    await make_account("u1")
    resp = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert_matches_contract(contract, "/v1/me", "get", 200, resp.json())
    assert resp.json()["onboarding"] == "consent"


async def test_target_y_recalculo_y_propuesta(
    client, zitadel, make_account, grant_consent, profile_body, contract
):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    r404 = await client.get("/v1/target", headers=h)
    assert_matches_contract(contract, "/v1/target", "get", 404, r404.json())
    r409 = await client.post("/v1/target/recalculate", headers=h)
    assert_matches_contract(contract, "/v1/target/recalculate", "post", 409, r409.json())
    await client.put("/v1/profile", json=profile_body(), headers=h)
    got = await client.get("/v1/target", headers=h)
    assert_matches_contract(contract, "/v1/target", "get", 200, got.json())
    applied = await client.put("/v1/profile", json=profile_body(goal="lose_fat"), headers=h)
    assert applied.json()["recalculation"]["status"] == "applied"
    assert_matches_contract(contract, "/v1/profile", "put", 200, applied.json())
    put = await client.put("/v1/target", json=got.json()["values"] | {"kcal": 2000}, headers=h)
    assert_matches_contract(contract, "/v1/target", "put", 200, put.json())
    bad = await client.put("/v1/target", json={"kcal": 0}, headers=h)
    assert_matches_contract(contract, "/v1/target", "put", 400, bad.json())
    proposed = await client.put("/v1/profile", json=profile_body(activity_level="high"), headers=h)
    assert proposed.json()["recalculation"]["status"] == "proposed"
    assert_matches_contract(contract, "/v1/profile", "put", 200, proposed.json())
    rec = await client.post("/v1/target/recalculate", headers=h)
    assert_matches_contract(contract, "/v1/target/recalculate", "post", 200, rec.json())
