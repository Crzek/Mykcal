"""US2/US3: recálculo al cambiar el perfil y objetivo editado a mano (research R12, SC-004)."""

from datetime import UTC, datetime, timedelta

from sqlalchemy import text

PROFILE, TARGET = "/v1/profile", "/v1/target"


async def versions(app) -> list[tuple[bool, str]]:
    async with app.state.sessionmaker() as s:
        rows = await s.execute(
            text("SELECT is_current, source FROM daily_target ORDER BY effective_from, id")
        )
        return [(r[0], r[1]) for r in rows]


async def start(client, zitadel, make_account, grant_consent, profile_body, **kw):
    await grant_consent(await make_account("u1"))
    h = zitadel.headers("u1")
    resp = await client.put(PROFILE, json=profile_body(**kw), headers=h)
    assert resp.status_code == 200
    return h


async def test_cambio_con_objetivo_calculado_se_recalcula(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    resp = await client.put(PROFILE, json=profile_body(goal="lose_fat"), headers=h)
    body = resp.json()
    assert body["recalculation"]["status"] == "applied"
    assert body["recalculation"]["previous"]["kcal"] == 2759
    v = body["target"]["values"]  # ejemplo de US2.3
    assert (v["kcal"], v["protein_g"], v["carbs_g"], v["fat_g"]) == (2207, 176, 238, 61)
    assert await versions(app) == [(False, "calculated"), (True, "calculated")]


async def test_sin_cambios_no_escribe(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    resp = await client.put(PROFILE, json=profile_body(), headers=h)
    assert resp.json()["recalculation"] == {"status": "none"}
    assert await versions(app) == [(True, "calculated")]


async def test_cambiar_solo_el_peso_cuenta_como_cambio(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    resp = await client.put(PROFILE, json=profile_body(weight_kg=85), headers=h)
    assert resp.json()["recalculation"]["status"] == "applied"
    assert resp.json()["target"]["calculation"]["weight_kg"] == 85.0


async def test_un_peso_posterior_al_calculo_no_dispara_recalculo_si_se_reenvia(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    """R12: reenviar el último peso registrado no cuenta como cambio de peso."""
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    async with app.state.sessionmaker() as s, s.begin():
        await s.execute(
            text(
                "INSERT INTO weight_entry (user_id, measured_on, weight_kg, created_at, "
                "updated_at) SELECT user_id, :d, 79.0, now(), now() FROM user_profile"
            ),
            {"d": datetime.now(UTC).date() + timedelta(days=1)},
        )
    same = await client.put(
        PROFILE,
        json=profile_body(
            weight_kg=79.0, measured_on=(datetime.now(UTC).date() + timedelta(days=1)).isoformat()
        ),
        headers=h,
    )
    # Mismo perfil que el cálculo y peso reenviado = último registro; pero el cálculo usó 80 kg.
    # Cambió solo el peso respecto al cálculo, no respecto al último registro: no se recalcula.
    assert same.json()["recalculation"]["status"] == "none"
    tall = await client.put(
        PROFILE,
        json=profile_body(
            weight_kg=79.0,
            height_cm=185,
            measured_on=(datetime.now(UTC).date() + timedelta(days=1)).isoformat(),
        ),
        headers=h,
    )
    assert tall.json()["recalculation"]["status"] == "applied"
    assert tall.json()["target"]["calculation"]["weight_kg"] == 79.0


async def test_recalculate_guarda_version_calculada(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    resp = await client.post(f"{TARGET}/recalculate", headers=h)
    assert resp.status_code == 200 and resp.json()["source"] == "calculated"
    assert await versions(app) == [(False, "calculated"), (True, "calculated")]


async def test_recalculate_sin_perfil(client, zitadel, make_account, grant_consent):
    await grant_consent(await make_account("u1"))
    resp = await client.post(f"{TARGET}/recalculate", headers=zitadel.headers("u1"))
    assert resp.status_code == 409 and resp.json()["code"] == "PROFILE_REQUIRED"


async def test_get_target_sin_objetivo(client, zitadel, make_account, grant_consent):
    await grant_consent(await make_account("u1"))
    resp = await client.get(TARGET, headers=zitadel.headers("u1"))
    assert resp.status_code == 404 and resp.json()["code"] == "TARGET_NOT_FOUND"


# --- US3: objetivo editado a mano -------------------------------------------------------------


async def manual_target(client, h, **over):
    current = (await client.get(TARGET, headers=h)).json()["values"]
    return await client.put(TARGET, json=current | over, headers=h)


async def test_objetivo_manual_solo_se_propone_y_no_cambia(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    await manual_target(client, h, kcal=2000)
    before = await versions(app)
    resp = await client.put(PROFILE, json=profile_body(activity_level="high"), headers=h)
    body = resp.json()
    assert body["recalculation"]["status"] == "proposed"
    assert body["recalculation"]["proposed"]["kcal"] != 2000
    assert body["target"]["values"]["kcal"] == 2000 and body["target"]["source"] == "manual"
    assert await versions(app) == before  # SC-004: no se escribió ninguna versión
    assert (await client.get(TARGET, headers=h)).json()["values"]["kcal"] == 2000


async def test_objetivo_manual_sin_cambios_en_el_perfil(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    await manual_target(client, h, kcal=2000)
    resp = await client.put(PROFILE, json=profile_body(), headers=h)
    assert resp.json()["recalculation"] == {"status": "none"}


async def test_volver_al_calculo_automatico(
    app, client, zitadel, make_account, grant_consent, profile_body
):
    h = await start(client, zitadel, make_account, grant_consent, profile_body)
    await manual_target(client, h, kcal=2000)
    resp = await client.post(f"{TARGET}/recalculate", headers=h)
    assert resp.status_code == 200
    assert resp.json()["source"] == "calculated" and resp.json()["values"]["kcal"] == 2759
