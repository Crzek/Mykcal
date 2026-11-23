"""US1/US2: perfil, peso y primer objetivo en una transacción (research R10, R11)."""

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import text

from mykcal.targets import service as targets_service

PROFILE = "/v1/profile"


async def counts(app) -> dict[str, int]:
    async with app.state.sessionmaker() as s:
        return {
            t: (await s.execute(text(f"SELECT count(*) FROM {t}"))).scalar_one()
            for t in ("user_profile", "weight_entry", "daily_target")
        }


async def onboarding(client, zitadel, sub) -> str:
    resp = await client.get("/v1/me", headers=zitadel.headers(sub))
    return resp.json()["onboarding"]


async def test_onboarding_avanza_consent_profile_done(
    client, zitadel, make_account, grant_consent, profile_body
):
    acc = await make_account("u1")
    h = zitadel.headers("u1")
    assert await onboarding(client, zitadel, "u1") == "consent"
    await grant_consent(acc)
    assert await onboarding(client, zitadel, "u1") == "profile"
    resp = await client.put(PROFILE, json=profile_body(), headers=h)
    assert resp.status_code == 200
    assert await onboarding(client, zitadel, "u1") == "done"


async def test_primer_guardado_crea_perfil_peso_y_objetivo(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    await grant_consent(await make_account("u1"))
    resp = await client.put(PROFILE, json=profile_body(), headers=zitadel.headers("u1"))
    assert resp.status_code == 200
    body = resp.json()
    assert body["recalculation"] == {"status": "created"}
    values = body["target"]["values"]
    # Ejemplo de US2.2: hombre, 30, 180 cm, 80 kg, moderada, mantener.
    assert (values["kcal"], values["protein_g"], values["carbs_g"], values["fat_g"]) == (
        2759,
        144,
        373,
        77,
    )
    assert body["target"]["source"] == "calculated"
    assert body["target"]["calculation"]["weight_kg"] == 80.0  # FR-006
    assert body["profile"]["weight_kg"] == 80.0
    assert await counts(app) == {"user_profile": 1, "weight_entry": 1, "daily_target": 1}


async def test_si_falla_el_calculo_no_queda_nada(
    app, client, zitadel, make_account, grant_consent, profile_body, monkeypatch
):
    await grant_consent(await make_account("u1"))

    async def boom(*_a, **_k):
        raise RuntimeError("fallo simulado")

    monkeypatch.setattr(targets_service, "save_version", boom)
    resp = await client.put(PROFILE, json=profile_body(), headers=zitadel.headers("u1"))
    assert resp.status_code == 500
    assert await counts(app) == {"user_profile": 0, "weight_entry": 0, "daily_target": 0}


async def test_get_profile_devuelve_el_peso_mas_reciente(
    client, zitadel, make_account, grant_consent, profile_body
):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    assert (await client.get(PROFILE, headers=h)).json()["code"] == "PROFILE_NOT_FOUND"
    today = datetime.now(UTC).date()
    await client.put(
        PROFILE,
        json=profile_body(weight_kg=80, measured_on=(today - timedelta(days=3)).isoformat()),
        headers=h,
    )
    await client.put(
        PROFILE, json=profile_body(weight_kg=78.4, measured_on=today.isoformat()), headers=h
    )
    got = (await client.get(PROFILE, headers=h)).json()
    assert got["weight_kg"] == 78.4 and got["weight_measured_on"] == today.isoformat()


@pytest.mark.parametrize(
    "override,field",
    [
        ({"age": 17}, "age"),
        ({"age": 101}, "age"),
        ({"height_cm": 30}, "height_cm"),
        ({"height_cm": 251}, "height_cm"),
        ({"weight_kg": 29.9}, "weight_kg"),
        ({"weight_kg": 300.1}, "weight_kg"),
        ({"weight_kg": 80.25}, "weight_kg"),
        ({"sex": "otro"}, "sex"),
        ({"activity_level": "mucha"}, "activity_level"),
        ({"goal": "volar"}, "goal"),
    ],
)
async def test_fuera_de_rango_no_escribe_nada(
    app, client, zitadel, make_account, grant_consent, profile_body, override, field
):
    await grant_consent(await make_account("u1"))
    resp = await client.put(PROFILE, json=profile_body(**override), headers=zitadel.headers("u1"))
    assert resp.status_code == 400
    assert resp.json()["code"] == "VALIDATION_ERROR"
    assert field in resp.json()["fields"]
    assert await counts(app) == {"user_profile": 0, "weight_entry": 0, "daily_target": 0}


@pytest.mark.parametrize("weight", [30, 80.3, 99.9, 300])
async def test_pesos_validos_con_un_decimal(
    client, zitadel, make_account, grant_consent, profile_body, weight
):
    await grant_consent(await make_account("u1"))
    resp = await client.put(
        PROFILE, json=profile_body(weight_kg=weight), headers=zitadel.headers("u1")
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["profile"]["weight_kg"] == weight


async def test_fecha_de_peso_muy_posterior_se_rechaza(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    await grant_consent(await make_account("u1"))
    future = (datetime.now(UTC) + timedelta(days=3)).date().isoformat()
    resp = await client.put(
        PROFILE, json=profile_body(measured_on=future), headers=zitadel.headers("u1")
    )
    assert resp.status_code == 400 and resp.json()["fields"] == ["measured_on"]
    assert await counts(app) == {"user_profile": 0, "weight_entry": 0, "daily_target": 0}
