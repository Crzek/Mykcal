"""T049 (US1, SC-002, SC-005)."""

from sqlalchemy import func, select

from mykcal.accounts.models import UserAccount


async def register(client, zitadel, sub, code):
    return await client.post(
        "/v1/registration", headers=zitadel.headers(sub), json={"invitation_code": code}
    )


async def count(app, status=None):
    async with app.state.sessionmaker() as s:
        q = select(func.count()).select_from(UserAccount)
        if status:
            q = q.where(UserAccount.status == status)
        return (await s.execute(q)).scalar_one()


async def test_codigo_vigente_crea_cuenta_activa(app, client, zitadel, seed_code):
    code = await seed_code()
    zitadel.names["u1"] = "Ana"
    resp = await register(client, zitadel, "u1", code)
    assert resp.status_code == 201
    body = resp.json()
    assert (
        body["display_name"] == "Ana" and body["status"] == "active" and body["is_admin"] is False
    )
    me = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert me.status_code == 200


async def test_normaliza_minusculas_espacios_y_guiones(app, client, zitadel, seed_code):
    await seed_code("ABCD2345")
    resp = await register(client, zitadel, "u1", "  abcd-2345 ")
    assert resp.status_code == 201


async def test_codigo_erroneo_no_crea_cuenta(app, client, zitadel, seed_code):
    await seed_code()
    before = await count(app)
    resp = await register(client, zitadel, "u1", "ZZZZ9999")
    assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_INVALID"
    assert await count(app) == before
    assert (await client.get("/v1/me", headers=zitadel.headers("u1"))).status_code == 404


async def test_codigo_sustituido_se_rechaza(app, client, zitadel, seed_code):
    await seed_code("ABCD2345")
    rot = await client.post("/v1/admin/invitation/rotate", headers=zitadel.headers("admin-sub"))
    assert rot.status_code == 200
    resp = await register(client, zitadel, "u1", "ABCD2345")
    assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_INVALID"
    ok = await register(client, zitadel, "u1", rot.json()["code"])
    assert ok.status_code == 201


async def test_cincuenta_activas_rechaza_aunque_el_codigo_sea_valido(
    app, client, zitadel, seed_code, make_account
):
    code = await seed_code()
    for i in range(49):  # + administrador = 50
        await make_account(f"existente-{i}")
    assert await count(app, "active") == 50
    resp = await register(client, zitadel, "nuevo", code)
    assert resp.status_code == 409 and resp.json()["code"] == "NO_SEATS"
    assert await count(app) == 50


async def test_desactivadas_no_cuentan_para_el_limite(
    app, client, zitadel, seed_code, make_account
):
    code = await seed_code()
    for i in range(48):
        await make_account(f"existente-{i}")
    await make_account("baja", status="disabled")
    assert await count(app, "active") == 49
    assert (await register(client, zitadel, "nuevo", code)).status_code == 201
    assert (await register(client, zitadel, "otro", code)).status_code == 409


async def test_ya_registrado(app, client, zitadel, seed_code):
    code = await seed_code()
    assert (await register(client, zitadel, "u1", code)).status_code == 201
    resp = await register(client, zitadel, "u1", code)
    assert resp.status_code == 409 and resp.json()["code"] == "ALREADY_REGISTERED"


async def test_admin_se_registra_sin_codigo_y_sin_codigo_vigente(app, client, zitadel):
    resp = await register(client, zitadel, "admin-sub", "")
    assert resp.status_code == 201 and resp.json()["is_admin"] is True
    assert await count(app, "active") == 1  # ocupa una plaza


async def test_no_admin_sin_codigo_vigente_recibe_invalido(app, client, zitadel):
    resp = await register(client, zitadel, "u1", "ABCD2345")
    assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_INVALID"


async def test_userinfo_caido_no_crea_cuenta(app, client, zitadel, seed_code):
    code = await seed_code()
    zitadel.userinfo_down = True
    resp = await register(client, zitadel, "u1", code)
    assert resp.status_code == 503 and resp.json()["code"] == "AUTH_UNAVAILABLE"
    assert await count(app) == 1  # solo el administrador sembrado


async def test_cuerpo_con_campos_extra_o_largo_da_400(client, zitadel):
    h = zitadel.headers("u1")
    assert (
        await client.post("/v1/registration", headers=h, json={"invitation_code": "A" * 33})
    ).status_code == 400
    assert (
        await client.post("/v1/registration", headers=h, json={"invitation_code": "A", "x": 1})
    ).status_code == 400


async def test_codigo_vacio_de_no_admin_pide_el_codigo_y_no_crea_cuenta(
    app, client, zitadel, seed_code, contract
):
    from tests.contract.schema import assert_matches_contract

    await seed_code()
    before = await count(app)
    for vacio in ("", " - "):
        resp = await register(client, zitadel, "u1", vacio)
        assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_REQUIRED"
        assert_matches_contract(contract, "/v1/registration", "post", 400, resp.json())
    assert await count(app) == before
    assert (await client.get("/v1/me", headers=zitadel.headers("u1"))).status_code == 404


async def test_ya_registrado_con_codigo_vacio_sigue_dando_409(client, zitadel, make_account):
    await make_account("u1")
    resp = await register(client, zitadel, "u1", "")
    assert resp.status_code == 409 and resp.json()["code"] == "ALREADY_REGISTERED"
