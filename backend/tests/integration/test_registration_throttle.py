"""T051 (FR-013): espera por identidad y bloqueo global."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select

from mykcal import clock
from mykcal.accounts.models import RegistrationFailure, RegistrationThrottle


async def register(client, zitadel, sub, code="ZZZZ9999"):
    return await client.post(
        "/v1/registration", headers=zitadel.headers(sub), json={"invitation_code": code}
    )


async def test_tras_el_cuarto_fallo_hay_429_sin_evaluar_el_codigo(client, zitadel, seed_code):
    code = await seed_code()
    for _ in range(4):
        assert (await register(client, zitadel, "u1")).status_code == 400
    # El 4.º fallo ya activa la espera (30 s); el código correcto tampoco se evalúa.
    resp = await register(client, zitadel, "u1", code)
    assert resp.status_code == 429 and resp.json()["code"] == "TOO_MANY_ATTEMPTS"
    assert 1 <= int(resp.headers["retry-after"]) <= 30
    assert resp.json()["retry_after_s"] == int(resp.headers["retry-after"])


async def test_pasada_la_espera_se_puede_volver_a_intentar_y_crece(
    client, zitadel, seed_code, monkeypatch
):
    await seed_code()
    base = datetime.now(UTC)
    now = {"t": base}
    monkeypatch.setattr(clock, "utcnow", lambda: now["t"])
    for _ in range(4):
        await register(client, zitadel, "u1")
    now["t"] = base + timedelta(seconds=31)
    assert (await register(client, zitadel, "u1")).status_code == 400  # 5.º fallo → espera 60 s
    resp = await register(client, zitadel, "u1")
    assert resp.status_code == 429 and 30 < int(resp.headers["retry-after"]) <= 60


async def test_alta_correcta_borra_la_fila(app, client, zitadel, seed_code):
    code = await seed_code()
    for _ in range(2):
        await register(client, zitadel, "u1")
    assert (await register(client, zitadel, "u1", code)).status_code == 201
    async with app.state.sessionmaker() as s:
        rows = (await s.execute(select(RegistrationThrottle))).scalars().all()
    assert rows == []


async def test_sin_plazas_y_ya_registrado_no_cuentan_como_fallo(
    app, client, zitadel, seed_code, make_account
):
    code = await seed_code()
    for i in range(49):
        await make_account(f"e-{i}")
    for _ in range(5):
        assert (await register(client, zitadel, "x", code)).status_code == 409
    async with app.state.sessionmaker() as s:
        assert (
            await s.execute(select(func.count()).select_from(RegistrationFailure))
        ).scalar_one() == 0


async def test_limite_global_entre_identidades_distintas(app, client, zitadel, seed_code):
    code = await seed_code()
    for i in range(20):  # 20 identidades, un fallo cada una (ninguna llega a su espera)
        assert (await register(client, zitadel, f"atacante-{i}")).status_code == 400
    resp = await register(client, zitadel, "legitimo", code)
    assert resp.status_code == 429 and resp.json()["code"] == "TOO_MANY_ATTEMPTS"
    assert int(resp.headers["retry-after"]) <= 600


async def test_con_19_fallos_no_bloquea(client, zitadel, seed_code):
    code = await seed_code()
    for i in range(19):
        await register(client, zitadel, f"atacante-{i}")
    assert (await register(client, zitadel, "legitimo", code)).status_code == 201


async def test_el_administrador_no_se_bloquea_ni_registra_fallos(app, client, zitadel):
    async with app.state.sessionmaker() as s, s.begin():
        now = datetime.now(UTC)
        s.add_all([RegistrationFailure(failed_at=now) for _ in range(25)])
    resp = await register(client, zitadel, "admin-sub", "")
    assert resp.status_code == 201


async def test_se_borran_los_fallos_de_mas_de_1h(app, client, zitadel, seed_code):
    await seed_code()
    async with app.state.sessionmaker() as s, s.begin():
        old = datetime.now(UTC) - timedelta(hours=2)
        s.add_all([RegistrationFailure(failed_at=old) for _ in range(30)])
    await register(client, zitadel, "u1")
    async with app.state.sessionmaker() as s:
        assert (
            await s.execute(select(func.count()).select_from(RegistrationFailure))
        ).scalar_one() == 1


async def test_codigo_vacio_no_cuenta_como_fallo(app, client, zitadel, seed_code):
    await seed_code()
    for _ in range(5):
        resp = await register(client, zitadel, "u1", "")
        assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_REQUIRED"
    async with app.state.sessionmaker() as s:
        n = (await s.execute(select(func.count()).select_from(RegistrationFailure))).scalar_one()
    assert n == 0
    resp = await register(client, zitadel, "u1", "ZZZZ9999")
    assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_INVALID"


async def test_codigo_vacio_se_evalua_antes_del_bloqueo(client, zitadel, seed_code):
    await seed_code()
    for _ in range(4):
        await register(client, zitadel, "u1")
    assert (await register(client, zitadel, "u1")).status_code == 429
    resp = await register(client, zitadel, "u1", "")
    assert resp.status_code == 400 and resp.json()["code"] == "INVITATION_REQUIRED"
