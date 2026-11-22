"""T050: plaza 50 y rotación durante un alta (SC-005)."""

import asyncio

from sqlalchemy import func, select

from mykcal.accounts.models import UserAccount


async def register(client, zitadel, sub, code):
    return await client.post(
        "/v1/registration", headers=zitadel.headers(sub), json={"invitation_code": code}
    )


async def test_dos_altas_simultaneas_con_49_cuentas_solo_una_gana(
    app, client, zitadel, seed_code, make_account
):
    code = await seed_code()
    for i in range(48):  # + administrador = 49
        await make_account(f"e-{i}")
    results = await asyncio.gather(
        register(client, zitadel, "a", code), register(client, zitadel, "b", code)
    )
    assert sorted(r.status_code for r in results) == [201, 409]
    assert [r for r in results if r.status_code == 409][0].json()["code"] == "NO_SEATS"
    async with app.state.sessionmaker() as s:
        active = (
            await s.execute(
                select(func.count()).select_from(UserAccount).where(UserAccount.status == "active")
            )
        ).scalar_one()
    assert active == 50


async def test_muchas_altas_simultaneas_nunca_superan_50(
    app, client, zitadel, seed_code, make_account
):
    code = await seed_code()
    for i in range(44):
        await make_account(f"e-{i}")  # 45 con el administrador
    results = await asyncio.gather(*[register(client, zitadel, f"n{i}", code) for i in range(12)])
    assert sum(r.status_code == 201 for r in results) == 5
    async with app.state.sessionmaker() as s:
        assert (await s.execute(select(func.count()).select_from(UserAccount))).scalar_one() == 50


async def test_rotacion_durante_el_alta_el_codigo_viejo_no_se_completa(
    app, client, zitadel, seed_code
):
    old = await seed_code("ABCD2345")
    rotate = client.post("/v1/admin/invitation/rotate", headers=zitadel.headers("admin-sub"))
    reg = register(client, zitadel, "u1", old)
    rot, res = await asyncio.gather(rotate, reg)
    assert rot.status_code == 200
    # O gana el alta (antes de rotar) o se rechaza: nunca se acepta un código ya sustituido.
    if res.status_code == 201:
        async with app.state.sessionmaker() as s:
            assert (
                await s.execute(select(UserAccount).where(UserAccount.subject == "u1"))
            ).scalar_one()
    else:
        assert res.json()["code"] == "INVITATION_INVALID"
    # Tras la rotación, el código viejo ya no vale para nadie.
    late = await register(client, zitadel, "u2", old)
    assert late.status_code == 400
