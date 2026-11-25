"""US3 (007): propuesta de recálculo, aceptar, ignorar y persistencia (FR-005–FR-008, R5)."""

import asyncio
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import text

NOW = datetime.now(UTC)
TODAY = NOW.date()
OFF = {"utc_offset_min": 0}
URL = "/v1/recalc-proposal"


@pytest.fixture
async def user(user_with_consent, make_target_version, make_profile):
    """Objetivo calculado con 80 kg (`make_target_version` usa calc_weight_kg=80)."""
    account, headers = await user_with_consent("recalc-u")
    await make_target_version(account, NOW - timedelta(days=30))
    await make_profile(account)
    return account, headers


async def weights(make_weight, account, *kgs, start_ago=0):
    for i, kg in enumerate(kgs):
        await make_weight(account, TODAY - timedelta(days=start_ago + i), kg)


async def rows(app, sql: str):
    async with app.state.sessionmaker() as s:
        return (await s.execute(text(sql))).all()


async def test_media_que_supera_el_umbral_propone(client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.1, 78.2, 78.3)  # media 78.2 (−2,25%)
    body = (await client.get(URL, params=OFF, headers=h)).json()
    assert body["status"] == "pending"
    assert (body["reference_weight_kg"], body["weekly_average_kg"]) == (80.0, 78.2)
    assert body["was_manual"] is False and body["large_change"] is False
    assert body["current"]["kcal"] == 2000 and body["proposed"]["kcal"] != 2000


async def test_propuesta_calcula_con_el_motor_de_objetivos(client, user, make_weight):
    from decimal import Decimal

    from mykcal.targets.calc import CalcInputs, calculate

    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    body = (await client.get(URL, params=OFF, headers=h)).json()
    expected = calculate(
        CalcInputs(
            sex="male",
            age=30,
            height_cm=180,
            weight_kg=Decimal("78.2"),
            activity_level="moderate",
            goal="maintain",
        )
    )
    assert body["proposed"]["kcal"] == expected.kcal


async def test_por_debajo_del_umbral_no_propone(client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.6, 78.6, 78.6)
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}


async def test_exactamente_dos_por_ciento_no_propone(client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.4, 78.4, 78.4)
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}


async def test_un_solo_registro_no_propone(client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 76.0)
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}


async def test_dos_llamadas_no_duplican_la_fila(app, client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    first = (await client.get(URL, params=OFF, headers=h)).json()
    second = (await client.get(URL, params=OFF, headers=h)).json()
    assert first == second
    assert len(await rows(app, "SELECT 1 FROM recalc_proposal WHERE status='pending'")) == 1


async def test_la_fila_pending_se_actualiza_y_desaparece(app, client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await client.get(URL, params=OFF, headers=h)
    await make_weight(account, TODAY - timedelta(days=3), 77.0)
    body = (await client.get(URL, params=OFF, headers=h)).json()
    assert body["weekly_average_kg"] == 77.9  # (78.2·3 + 77.0) / 4 = 77.9
    assert len(await rows(app, "SELECT 1 FROM recalc_proposal")) == 1
    # Los registros nuevos devuelven la media por debajo del umbral: la fila desaparece
    await client.put(f"/v1/weight/{TODAY}", json={"weight_kg": 82.0}, params=OFF, headers=h)
    await client.put(
        f"/v1/weight/{TODAY - timedelta(days=1)}", json={"weight_kg": 82.0}, params=OFF, headers=h
    )
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}
    assert await rows(app, "SELECT 1 FROM recalc_proposal") == []


async def test_variacion_grande_y_objetivo_manual(client, user, make_weight, make_target_version):
    account, h = user
    await weights(make_weight, account, 70.0, 70.0, 70.0)
    assert (await client.get(URL, params=OFF, headers=h)).json()["large_change"] is True
    manual = (await client.get("/v1/target", headers=h)).json()["values"] | {"kcal": 2500}
    assert (await client.put("/v1/target", json=manual, headers=h)).status_code == 200
    assert (await client.get(URL, params=OFF, headers=h)).json()["was_manual"] is True


async def test_aceptar_recalcula_y_marca_accepted(app, client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await client.get(URL, params=OFF, headers=h)
    resp = await client.post(f"{URL}/accept", params=OFF, headers=h)
    assert resp.status_code == 200
    body = resp.json()
    assert body["source"] == "calculated" and body["calculation"]["weight_kg"] == 78.2
    stored = await rows(app, "SELECT status, responded_at IS NOT NULL FROM recalc_proposal")
    assert [tuple(r) for r in stored] == [("accepted", True)]
    versions = await rows(app, "SELECT is_current FROM daily_target ORDER BY effective_from")
    assert [r[0] for r in versions] == [False, True]
    # La referencia ahora es 78.2: ya no hay propuesta
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}


async def test_aceptar_no_cambia_el_objetivo_de_dias_pasados(client, user, make_weight):
    account, h = user
    old = (await client.get("/v1/target", headers=h)).json()["values"]
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await client.get(URL, params=OFF, headers=h)
    await client.post(f"{URL}/accept", params=OFF, headers=h)
    yesterday = TODAY - timedelta(days=1)
    day = (await client.get(f"/v1/diary/days/{yesterday}", params=OFF, headers=h)).json()
    assert day["target"]["kcal"] == old["kcal"]


async def test_ignorar_bloquea_siete_dias(app, client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await client.get(URL, params=OFF, headers=h)
    assert (await client.post(f"{URL}/ignore", params=OFF, headers=h)).status_code == 204
    stored = await rows(app, "SELECT status, ignored_until FROM recalc_proposal")
    assert (stored[0][0], stored[0][1]) == ("ignored", TODAY + timedelta(days=7))
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}


async def test_ignorada_vuelve_a_proponer_pasado_el_plazo(
    app, client, user, make_weight, make_proposal
):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await make_proposal(account, "ignored", ignored_until=TODAY)  # vence hoy
    assert (await client.get(URL, params=OFF, headers=h)).json()["status"] == "pending"
    assert len(await rows(app, "SELECT 1 FROM recalc_proposal")) == 2


async def test_ignorada_vigente_bloquea(client, user, make_weight, make_proposal):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await make_proposal(account, "ignored", ignored_until=TODAY + timedelta(days=1))
    assert (await client.get(URL, params=OFF, headers=h)).json() == {"status": "none"}


async def test_aceptar_o_ignorar_sin_propuesta_es_409(client, user):
    _, h = user
    for action in ("accept", "ignore"):
        resp = await client.post(f"{URL}/{action}", params=OFF, headers=h)
        assert resp.status_code == 409 and resp.json()["code"] == "RECALC_NO_PROPOSAL"


async def test_guardar_un_peso_reevalua_la_propuesta(app, client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, start_ago=1)
    assert await rows(app, "SELECT 1 FROM recalc_proposal") == []
    resp = await client.post(
        "/v1/weight",
        json={"measured_on": TODAY.isoformat(), "weight_kg": 78.2},
        params=OFF,
        headers=h,
    )
    assert resp.status_code == 200
    assert len(await rows(app, "SELECT 1 FROM recalc_proposal WHERE status='pending'")) == 1


async def test_objetivo_manual_no_cambia_sin_aceptar(client, user, make_weight):
    account, h = user
    manual = (await client.get("/v1/target", headers=h)).json()["values"] | {"kcal": 2500}
    await client.put("/v1/target", json=manual, headers=h)
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    await client.get(URL, params=OFF, headers=h)
    target = (await client.get("/v1/target", headers=h)).json()
    assert target["source"] == "manual" and target["values"]["kcal"] == 2500


async def test_evaluaciones_concurrentes_dejan_una_sola_pending(app, client, user, make_weight):
    account, h = user
    await weights(make_weight, account, 78.2, 78.2, 78.2)
    results = await asyncio.gather(*(client.get(URL, params=OFF, headers=h) for _ in range(4)))
    assert all(r.status_code == 200 and r.json()["status"] == "pending" for r in results)
    assert len(await rows(app, "SELECT 1 FROM recalc_proposal WHERE status='pending'")) == 1
