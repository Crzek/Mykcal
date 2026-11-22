"""T060 (US4, SC-004)."""

from sqlalchemy import select

from mykcal.invitations.models import InvitationCode

H = "/v1/admin/invitation"


async def test_estado_sin_codigo(client, zitadel, make_account):
    await make_account("admin-sub")
    resp = await client.get(H, headers=zitadel.headers("admin-sub"))
    assert resp.status_code == 200
    assert resp.json() == {
        "code": None,
        "created_at": None,
        "active_accounts": 1,
        "max_accounts": 50,
        "free_seats": 49,
    }


async def test_estado_con_codigo_y_plazas(client, zitadel, seed_code, make_account):
    await seed_code("ABCD2345")
    await make_account("u1")
    await make_account("baja", status="disabled")
    body = (await client.get(H, headers=zitadel.headers("admin-sub"))).json()
    assert body["code"] == "ABCD2345"
    assert body["active_accounts"] == 2 and body["free_seats"] == 48


async def test_rotar_deja_un_solo_vigente_y_conserva_el_historico(app, client, zitadel, seed_code):
    await seed_code("ABCD2345")
    first = (await client.post(H + "/rotate", headers=zitadel.headers("admin-sub"))).json()
    second = (await client.post(H + "/rotate", headers=zitadel.headers("admin-sub"))).json()
    assert len({"ABCD2345", first["code"], second["code"]}) == 3
    async with app.state.sessionmaker() as s:
        rows = (
            (await s.execute(select(InvitationCode).order_by(InvitationCode.created_at)))
            .scalars()
            .all()
        )
    assert len(rows) == 3
    assert [r.is_current for r in rows].count(True) == 1
    assert rows[-1].code == second["code"] and rows[-1].is_current
    assert all(r.superseded_at is not None for r in rows[:-1])


async def test_codigo_anterior_deja_de_valer_y_el_nuevo_si(
    client, zitadel, seed_code, make_account
):
    await seed_code("ABCD2345")
    await make_account("existente")
    new = (await client.post(H + "/rotate", headers=zitadel.headers("admin-sub"))).json()["code"]
    old = await client.post(
        "/v1/registration", headers=zitadel.headers("u1"), json={"invitation_code": "ABCD2345"}
    )
    assert old.status_code == 400
    ok = await client.post(
        "/v1/registration", headers=zitadel.headers("u2"), json={"invitation_code": new}
    )
    assert ok.status_code == 201
    # Las cuentas existentes no se ven afectadas.
    assert (await client.get("/v1/me", headers=zitadel.headers("existente"))).status_code == 200


async def test_no_admin_recibe_403(client, zitadel, make_account):
    await make_account("u1")
    for method, path in [("GET", H), ("POST", H + "/rotate")]:
        resp = await client.request(method, path, headers=zitadel.headers("u1"))
        assert resp.status_code == 403 and resp.json()["code"] == "FORBIDDEN"


async def test_el_primer_codigo_lo_genera_el_admin_registrado_sin_codigo(client, zitadel):
    reg = await client.post(
        "/v1/registration", headers=zitadel.headers("admin-sub"), json={"invitation_code": ""}
    )
    assert reg.status_code == 201
    rot = await client.post(H + "/rotate", headers=zitadel.headers("admin-sub"))
    assert rot.status_code == 200 and len(rot.json()["code"]) == 8
