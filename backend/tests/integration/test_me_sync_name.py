"""T031: sincronía del nombre visible cada 24 h."""

from datetime import timedelta

from sqlalchemy import select

from mykcal import clock
from mykcal.accounts.models import UserAccount


async def get_account(app, sub):
    async with app.state.sessionmaker() as s:
        return (await s.execute(select(UserAccount).where(UserAccount.subject == sub))).scalar_one()


async def test_no_llama_a_userinfo_antes_de_24h(app, client, zitadel, make_account):
    await make_account("u1", name="Vieja")
    await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert zitadel.userinfo_calls == 0


async def test_actualiza_tras_24h(app, client, zitadel, make_account, monkeypatch):
    await make_account("u1", name="Vieja")
    zitadel.names["u1"] = "Nueva"
    monkeypatch.setattr(
        clock, "utcnow", lambda: clock.datetime.now(clock.UTC) + timedelta(hours=25)
    )
    resp = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert resp.json()["display_name"] == "Nueva"
    assert (await get_account(app, "u1")).display_name == "Nueva"


async def test_conserva_el_nombre_si_userinfo_falla(
    app, client, zitadel, make_account, monkeypatch
):
    await make_account("u1", name="Vieja")
    zitadel.userinfo_down = True
    monkeypatch.setattr(
        clock, "utcnow", lambda: clock.datetime.now(clock.UTC) + timedelta(hours=25)
    )
    resp = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert resp.status_code == 200 and resp.json()["display_name"] == "Vieja"


async def test_el_email_no_se_guarda(app, client, zitadel, make_account):
    await make_account("u1")
    async with app.state.sessionmaker() as s:
        cols = (await s.execute(select(UserAccount))).scalars().first().__table__.columns.keys()
    assert "email" not in cols
