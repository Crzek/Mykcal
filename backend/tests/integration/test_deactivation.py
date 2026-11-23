"""US4: baja de la cuenta (FR-018, FR-019, research R15)."""

import asyncio

from sqlalchemy import text

URL = "/v1/me/deactivation"


async def account_row(app, sub):
    async with app.state.sessionmaker() as s:
        row = await s.execute(
            text("SELECT status, disabled_at FROM user_account WHERE subject = :s"), {"s": sub}
        )
        return row.one()


async def test_baja_desactiva_y_conserva_los_datos(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    await client.put("/v1/profile", json=profile_body(), headers=h)
    resp = await client.post(URL, headers=h)
    assert resp.status_code == 204
    status, disabled_at = await account_row(app, "u1")
    assert status == "disabled" and disabled_at is not None
    async with app.state.sessionmaker() as s:
        for table in ("user_profile", "weight_entry", "daily_target", "health_consent"):
            assert (await s.execute(text(f"SELECT count(*) FROM {table}"))).scalar_one() == 1


async def test_con_el_mismo_token_ya_no_opera(
    client, zitadel, make_account, grant_consent, profile_body
):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    await client.put("/v1/profile", json=profile_body(), headers=h)
    await client.post(URL, headers=h)
    for method, path in (("GET", "/v1/profile"), ("GET", "/v1/target"), ("POST", URL)):
        resp = await client.request(method, path, headers=h)
        assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_DISABLED", path
    me = await client.get("/v1/me", headers=h)
    assert me.status_code == 200 and me.json()["status"] == "disabled"


async def test_baja_sin_consentimiento(app, client, zitadel, make_account):
    await make_account("u1")  # sin consentimiento: puede darse de baja (US1.2 / G1)
    resp = await client.post(URL, headers=zitadel.headers("u1"))
    assert resp.status_code == 204
    assert (await account_row(app, "u1"))[0] == "disabled"


async def test_la_plaza_se_libera(app, client, zitadel, seed_code, make_account):
    code = await seed_code()
    for i in range(48):  # + administrador = 49
        await make_account(f"e-{i}")
    await make_account("saliente")  # 50 activas
    full = await client.post(
        "/v1/registration", headers=zitadel.headers("nuevo"), json={"invitation_code": code}
    )
    assert full.status_code == 409 and full.json()["code"] == "NO_SEATS"
    assert (await client.post(URL, headers=zitadel.headers("saliente"))).status_code == 204
    ok = await client.post(
        "/v1/registration", headers=zitadel.headers("nuevo"), json={"invitation_code": code}
    )
    assert ok.status_code == 201


async def test_baja_y_alta_simultaneas_no_superan_50(app, client, zitadel, seed_code, make_account):
    code = await seed_code()
    for i in range(48):
        await make_account(f"e-{i}")
    await make_account("saliente")  # 50 activas
    results = await asyncio.gather(
        client.post(URL, headers=zitadel.headers("saliente")),
        client.post(
            "/v1/registration", headers=zitadel.headers("nuevo"), json={"invitation_code": code}
        ),
    )
    assert results[0].status_code == 204
    assert results[1].status_code in (201, 409)
    async with app.state.sessionmaker() as s:
        active = (
            await s.execute(text("SELECT count(*) FROM user_account WHERE status = 'active'"))
        ).scalar_one()
    assert active <= 50


async def test_se_registra_el_evento_sin_sub(app, client, zitadel, make_account, capsys):
    await make_account("sub-secreto-baja")
    capsys.readouterr()
    await client.post(URL, headers=zitadel.headers("sub-secreto-baja"))
    out = capsys.readouterr().out
    assert "account_deactivated" in out and "sub-secreto-baja" not in out
