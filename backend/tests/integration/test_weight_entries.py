"""US1 (007): registrar, sustituir, corregir y borrar pesos (FR-001, FR-002, R2)."""

from datetime import UTC, datetime, timedelta

import pytest

NOW = datetime.now(UTC)
TODAY = NOW.date()
OFF = {"utc_offset_min": 0}


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("weight-u")
    await make_target_version(account, NOW - timedelta(days=30))
    return account, headers


async def post(client, headers, day, kg, **params):
    return await client.post(
        "/v1/weight",
        json={"measured_on": day.isoformat(), "weight_kg": kg},
        params={**OFF, **params},
        headers=headers,
    )


async def test_crea_y_sustituye_el_registro_del_dia(client, user):
    _, h = user
    first = await post(client, h, TODAY, 78.4)
    assert first.status_code == 200 and first.json()["weight_kg"] == 78.4
    second = await post(client, h, TODAY, 78.9)
    assert second.status_code == 200
    assert second.json()["updated_at"] >= first.json()["updated_at"]
    entries = (await client.get("/v1/weight", headers=h)).json()["entries"]
    assert [(e["measured_on"], e["weight_kg"]) for e in entries] == [(TODAY.isoformat(), 78.9)]


async def test_dia_pasado_sin_registro_lo_crea(client, user):
    _, h = user
    day = TODAY - timedelta(days=1)  # el alta es de hoy: se permite alta − 1 día
    assert (await post(client, h, day, 79.0)).status_code == 200
    entries = (await client.get("/v1/weight", headers=h)).json()["entries"]
    assert entries[0]["measured_on"] == day.isoformat()


async def test_put_edita_y_delete_borra(client, user):
    _, h = user
    await post(client, h, TODAY, 78.4)
    put = await client.put(f"/v1/weight/{TODAY}", json={"weight_kg": 77.0}, params=OFF, headers=h)
    assert put.status_code == 200 and put.json()["weight_kg"] == 77.0
    delete = await client.delete(f"/v1/weight/{TODAY}", params=OFF, headers=h)
    assert delete.status_code == 204
    assert (await client.get("/v1/weight", headers=h)).json()["entries"] == []


async def test_put_y_delete_de_dia_sin_registro_dan_404(client, user):
    _, h = user
    put = await client.put(f"/v1/weight/{TODAY}", json={"weight_kg": 77.0}, params=OFF, headers=h)
    delete = await client.delete(f"/v1/weight/{TODAY}", params=OFF, headers=h)
    for resp in (put, delete):
        assert resp.status_code == 404 and resp.json()["code"] == "WEIGHT_NOT_FOUND"


@pytest.mark.parametrize("kg", [29.9, 300.1, 78.44, 0, -5])
async def test_peso_fuera_de_rango_o_con_mas_de_un_decimal(client, user, kg):
    _, h = user
    resp = await post(client, h, TODAY, kg)
    assert resp.status_code == 400 and resp.json()["code"] == "VALIDATION_ERROR"
    assert resp.json()["fields"] == ["weight_kg"]


@pytest.mark.parametrize("kg", [30.0, 300.0])
async def test_limites_del_rango_son_validos(client, user, kg):
    _, h = user
    assert (await post(client, h, TODAY, kg)).status_code == 200


async def test_sin_utc_offset_min_es_400(client, user):
    _, h = user
    body = {"measured_on": TODAY.isoformat(), "weight_kg": 78}
    assert (await client.post("/v1/weight", json=body, headers=h)).status_code == 400
    assert (
        await client.put(f"/v1/weight/{TODAY}", json={"weight_kg": 78}, headers=h)
    ).status_code == 400
    assert (await client.delete(f"/v1/weight/{TODAY}", headers=h)).status_code == 400


async def test_fecha_futura_local_y_anterior_al_alta_dan_400(client, user):
    _, h = user
    # Con desfase +600 min (UTC+10) «hoy» local puede ser mañana UTC: el día siguiente local falla.
    local_today = (datetime.now(UTC) + timedelta(minutes=600)).date()
    ok = await post(client, h, local_today, 78.0, utc_offset_min=600)
    assert ok.status_code == 200
    tomorrow = await post(client, h, local_today + timedelta(days=1), 78.0, utc_offset_min=600)
    assert tomorrow.status_code == 400 and tomorrow.json()["code"] == "VALIDATION_ERROR"
    assert tomorrow.json()["fields"] == ["measured_on"]
    # Con UTC−10 el día local puede ser el anterior a hoy UTC y sigue siendo válido
    local_west = (datetime.now(UTC) + timedelta(minutes=-600)).date()
    assert (await post(client, h, local_west, 78.0, utc_offset_min=-600)).status_code == 200
    before_signup = await post(client, h, TODAY - timedelta(days=5), 78.0)
    assert before_signup.status_code == 400 and before_signup.json()["fields"] == ["measured_on"]


async def test_lista_filtra_y_ordena_descendente(client, user, make_weight):
    account, h = user
    for ago, kg in [(0, 78.0), (1, 78.1), (2, 78.2)]:
        await make_weight(account, TODAY - timedelta(days=ago), kg)
    resp = await client.get("/v1/weight", headers=h)
    days = [e["measured_on"] for e in resp.json()["entries"]]
    assert days == sorted(days, reverse=True) and len(days) == 3
    only = await client.get(
        "/v1/weight",
        params={
            "from": (TODAY - timedelta(days=1)).isoformat(),
            "to": (TODAY - timedelta(days=1)).isoformat(),
        },
        headers=h,
    )
    assert [e["weight_kg"] for e in only.json()["entries"]] == [78.1]


async def test_sin_consentimiento_403(client, zitadel, make_account):
    await make_account("sin-consent")
    resp = await client.get("/v1/weight", headers=zitadel.headers("sin-consent"))
    assert resp.status_code == 403 and resp.json()["code"] == "CONSENT_REQUIRED"
