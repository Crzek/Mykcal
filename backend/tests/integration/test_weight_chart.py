"""US2 (007): serie de la gráfica y resumen (FR-003, FR-004, R4)."""

from datetime import UTC, datetime, timedelta

import pytest

NOW = datetime.now(UTC)
TODAY = NOW.date()
OFF = {"utc_offset_min": 0}


@pytest.fixture
async def user(user_with_consent):
    return await user_with_consent("chart-u")


async def chart(client, headers, period="p30"):
    resp = await client.get("/v1/weight/chart", params={"period": period, **OFF}, headers=headers)
    assert resp.status_code == 200, resp.text
    return resp.json()


async def test_periodos_recortan_los_puntos(client, user, make_weight):
    account, h = user
    for ago in (0, 10, 29, 30, 89, 90, 200):
        await make_weight(account, TODAY - timedelta(days=ago), 80.0)
    assert len((await chart(client, h, "p30"))["points"]) == 3  # 0, 10, 29
    assert len((await chart(client, h, "p90"))["points"]) == 5  # + 30, 89
    assert len((await chart(client, h, "all"))["points"]) == 7


async def test_dias_sin_registro_no_aparecen_y_la_media_exige_tres(client, user, make_weight):
    account, h = user
    for ago, kg in [(5, 79.0), (3, 78.0), (0, 77.0)]:
        await make_weight(account, TODAY - timedelta(days=ago), kg)
    points = (await chart(client, h))["points"]
    assert [p["date"] for p in points] == [
        (TODAY - timedelta(days=d)).isoformat() for d in (5, 3, 0)
    ]
    assert [p["average_kg"] for p in points] == [None, None, 78.0]


async def test_resumen(client, user, make_weight):
    account, h = user
    for ago, kg in [(10, 80.0), (2, 78.5), (1, 78.0), (0, 77.5)]:
        await make_weight(account, TODAY - timedelta(days=ago), kg)
    summary = (await chart(client, h))["summary"]
    assert summary == {
        "count": 4,
        "current_weight_kg": 77.5,
        "weekly_average_kg": 78.0,
        "change_kg": -2.5,
    }


async def test_ventana_del_primer_dia_cruza_el_inicio_del_periodo(client, user, make_weight):
    account, h = user
    first_day = TODAY - timedelta(days=29)
    for ago, kg in [(31, 80.0), (30, 80.0), (29, 78.0)]:
        await make_weight(account, TODAY - timedelta(days=ago), kg)
    points = (await chart(client, h, "p30"))["points"]
    assert points[0]["date"] == first_day.isoformat()
    assert points[0]["average_kg"] == 79.3


async def test_pocos_registros_devuelven_200_con_resumen_nulo(client, user, make_weight):
    account, h = user
    empty = await chart(client, h)
    assert empty["points"] == [] and empty["summary"]["count"] == 0
    assert empty["summary"]["current_weight_kg"] is None
    await make_weight(account, TODAY, 80.0)
    one = await chart(client, h)
    assert len(one["points"]) == 1 and one["summary"]["change_kg"] is None


async def test_periodo_invalido_es_400(client, user):
    _, h = user
    resp = await client.get("/v1/weight/chart", params={"period": "p7", **OFF}, headers=h)
    assert resp.status_code == 400 and resp.json()["code"] == "VALIDATION_ERROR"
