"""US1: consentimiento de datos de salud (FR-001–FR-003, research R8)."""

from sqlalchemy import text

from mykcal.consent.service import CURRENT_CONSENT_VERSION

URL = "/v1/consent"


async def count(app) -> int:
    async with app.state.sessionmaker() as s:
        return (await s.execute(text("SELECT count(*) FROM health_consent"))).scalar_one()


async def test_acepta_la_version_vigente_con_hora_del_servidor(app, client, zitadel, make_account):
    await make_account("u1")
    resp = await client.post(
        URL, json={"text_version": CURRENT_CONSENT_VERSION}, headers=zitadel.headers("u1")
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["text_version"] == CURRENT_CONSENT_VERSION
    assert body["accepted_at"]
    assert await count(app) == 1


async def test_repetir_la_misma_version_es_idempotente(app, client, zitadel, make_account):
    await make_account("u1")
    h = zitadel.headers("u1")
    first = await client.post(URL, json={"text_version": CURRENT_CONSENT_VERSION}, headers=h)
    second = await client.post(URL, json={"text_version": CURRENT_CONSENT_VERSION}, headers=h)
    assert second.status_code == 201
    assert second.json()["accepted_at"] == first.json()["accepted_at"]
    assert await count(app) == 1


async def test_version_desconocida(app, client, zitadel, make_account):
    await make_account("u1")
    resp = await client.post(URL, json={"text_version": "1999-01-1"}, headers=zitadel.headers("u1"))
    assert resp.status_code == 409 and resp.json()["code"] == "CONSENT_VERSION_MISMATCH"
    assert await count(app) == 0


async def test_sin_cuenta_y_desactivada(client, zitadel, make_account):
    await make_account("dis", status="disabled")
    body = {"text_version": CURRENT_CONSENT_VERSION}
    sin = await client.post(URL, json=body, headers=zitadel.headers("nadie"))
    assert sin.status_code == 403 and sin.json()["code"] == "ACCOUNT_NOT_REGISTERED"
    dis = await client.post(URL, json=body, headers=zitadel.headers("dis"))
    assert dis.status_code == 403 and dis.json()["code"] == "ACCOUNT_DISABLED"


async def test_cuerpo_invalido_devuelve_solo_nombres_de_campo(client, zitadel, make_account):
    await make_account("u1")
    resp = await client.post(URL, json={"text_version": ""}, headers=zitadel.headers("u1"))
    assert resp.status_code == 400
    assert resp.json()["code"] == "VALIDATION_ERROR"
    assert resp.json()["fields"] == ["text_version"]
