"""Aislamiento por usuario de perfil, peso y objetivo (principio V)."""

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]


async def test_cada_usuario_ve_solo_lo_suyo(
    client, zitadel, make_account, grant_consent, profile_body
):
    for sub in ("a", "b"):
        await grant_consent(await make_account(sub))
    ha, hb = zitadel.headers("a"), zitadel.headers("b")
    await client.put("/v1/profile", json=profile_body(age=31, weight_kg=81.5), headers=ha)
    await client.put(
        "/v1/profile", json=profile_body(age=52, sex="female", weight_kg=62), headers=hb
    )

    pa = (await client.get("/v1/profile", headers=ha)).json()
    pb = (await client.get("/v1/profile", headers=hb)).json()
    assert (pa["age"], pa["weight_kg"], pa["sex"]) == (31, 81.5, "male")
    assert (pb["age"], pb["weight_kg"], pb["sex"]) == (52, 62.0, "female")
    ta = (await client.get("/v1/target", headers=ha)).json()
    tb = (await client.get("/v1/target", headers=hb)).json()
    assert ta["calculation"]["age"] == 31 and tb["calculation"]["age"] == 52


async def test_guardar_el_de_a_no_cambia_el_de_b(
    client, zitadel, make_account, grant_consent, profile_body
):
    for sub in ("a", "b"):
        await grant_consent(await make_account(sub))
    ha, hb = zitadel.headers("a"), zitadel.headers("b")
    await client.put("/v1/profile", json=profile_body(age=40), headers=hb)
    before = (await client.get("/v1/target", headers=hb)).json()
    await client.put("/v1/profile", json=profile_body(age=25, goal="lose_fat"), headers=ha)
    await client.put("/v1/target", json=before["values"] | {"kcal": 1800}, headers=ha)
    assert (await client.get("/v1/target", headers=hb)).json() == before
    assert (await client.get("/v1/profile", headers=hb)).json()["age"] == 40
