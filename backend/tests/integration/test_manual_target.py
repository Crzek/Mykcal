"""US3: PUT /v1/target (FR-014, research R13)."""

import pytest
from sqlalchemy import text

TARGET = "/v1/target"


async def setup(client, zitadel, make_account, grant_consent, profile_body):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    await client.put("/v1/profile", json=profile_body(), headers=h)
    return h


async def test_guarda_version_manual_y_copia_los_datos_del_calculo(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await setup(client, zitadel, make_account, grant_consent, profile_body)
    before = (await client.get(TARGET, headers=h)).json()
    resp = await client.put(
        TARGET, json=before["values"] | {"kcal": 2400, "protein_g": 150}, headers=h
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["source"] == "manual"
    assert body["values"]["kcal"] == 2400 and body["values"]["protein_g"] == 150
    assert body["calculation"] == before["calculation"]  # FR-013


async def test_dos_guardados_dejan_una_sola_vigente(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await setup(client, zitadel, make_account, grant_consent, profile_body)
    values = (await client.get(TARGET, headers=h)).json()["values"]
    await client.put(TARGET, json=values | {"kcal": 2300}, headers=h)
    await client.put(TARGET, json=values | {"kcal": 2200}, headers=h)
    async with app.state.sessionmaker() as s:
        rows = (await s.execute(text("SELECT is_current FROM daily_target"))).all()
    assert len(rows) == 3 and sum(r[0] for r in rows) == 1


@pytest.mark.parametrize(
    "override",
    [
        {"kcal": 0},
        {"kcal": 10001},
        {"protein_g": -1},
        {"protein_g": 1.5},
        {"carbs_g": "mucho"},
        {"fiber_g": 201},
        {"sodium_mg": 20001},
    ],
)
async def test_valores_invalidos(
    client, zitadel, make_account, grant_consent, profile_body, override
):
    h = await setup(client, zitadel, make_account, grant_consent, profile_body)
    values = (await client.get(TARGET, headers=h)).json()["values"]
    resp = await client.put(TARGET, json=values | override, headers=h)
    assert resp.status_code == 400 and resp.json()["code"] == "VALIDATION_ERROR"
    assert list(override)[0] in resp.json()["fields"]


async def test_valor_ausente(client, zitadel, make_account, grant_consent, profile_body):
    h = await setup(client, zitadel, make_account, grant_consent, profile_body)
    values = (await client.get(TARGET, headers=h)).json()["values"]
    values.pop("iron_mg")
    resp = await client.put(TARGET, json=values, headers=h)
    assert resp.status_code == 400 and "iron_mg" in resp.json()["fields"]


async def test_sin_perfil(client, zitadel, make_account, grant_consent):
    await grant_consent(await make_account("u1"))
    values = {
        "kcal": 2000, "protein_g": 100, "carbs_g": 200, "fat_g": 60, "fiber_g": 30,
        "sodium_mg": 2000, "potassium_mg": 3500, "calcium_mg": 1000, "iron_mg": 8,
        "magnesium_mg": 400, "vitamin_d_ug": 15, "vitamin_c_mg": 90,
    }  # fmt: skip
    resp = await client.put(TARGET, json=values, headers=zitadel.headers("u1"))
    assert resp.status_code == 409 and resp.json()["code"] == "PROFILE_REQUIRED"
