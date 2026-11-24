"""T018 (004): GET /v1/diary/days/{date} (FR-006–FR-009, FR-011)."""

from datetime import UTC, date, datetime, timedelta

import pytest

MEALS = ["breakfast", "lunch", "afternoon_snack", "dinner", "snacks"]
TODAY = datetime.now(UTC).date()


def url(day: date, offset: int = 0) -> str:
    return f"/v1/diary/days/{day.isoformat()}?utc_offset_min={offset}"


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("diary-user")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=30))
    return account, headers


async def test_dia_sin_entradas(client, user):
    _, headers = user
    resp = await client.get(url(TODAY), headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["date"] == TODAY.isoformat()
    assert body["totals"]["consumed"]["kcal"] == 0
    assert body["remaining"]["kcal"] == 2000 and body["target"]["kcal"] == 2000
    assert [m["meal"] for m in body["meals"]] == MEALS
    assert all(m["entries"] == [] for m in body["meals"])


async def test_dia_con_entradas_en_varias_comidas(client, user, make_entry):
    account, headers = user
    await make_entry(account, TODAY, "breakfast", kcal=200, protein_g=10, quantity=150)
    await make_entry(account, TODAY, "dinner", kcal=100, quantity=100)
    body = (await client.get(url(TODAY), headers=headers)).json()
    by_meal = {m["meal"]: m for m in body["meals"]}
    assert by_meal["breakfast"]["totals"]["consumed"]["kcal"] == 300
    assert by_meal["breakfast"]["entries"][0]["values"]["kcal"] == 300
    assert by_meal["breakfast"]["entries"][0]["per_100"]["kcal"] == 200
    assert by_meal["dinner"]["totals"]["consumed"]["kcal"] == 100
    assert body["totals"]["consumed"]["kcal"] == 400
    assert body["remaining"]["kcal"] == 1600
    assert body["totals"]["consumed"]["protein_g"] == 25.0  # 10 g/100 × 150 g + 10 g/100 × 100 g
    # Fibra sin dato en los alimentos de prueba: cuenta como 0 e «incompleto» (FR-008)
    assert "fiber_g" in body["totals"]["incomplete"]


async def test_una_entrada_borrada_no_se_devuelve_ni_suma(client, user, make_entry):
    account, headers = user
    await make_entry(account, TODAY, "lunch", kcal=500, deleted_at=datetime.now(UTC))
    body = (await client.get(url(TODAY), headers=headers)).json()
    assert body["totals"]["consumed"]["kcal"] == 0
    assert all(m["entries"] == [] for m in body["meals"])


async def test_solo_entradas_del_dia_pedido(client, user, make_entry):
    account, headers = user
    ayer = TODAY - timedelta(days=1)
    await make_entry(account, ayer, "lunch", kcal=500)
    assert (await client.get(url(TODAY), headers=headers)).json()["totals"]["consumed"]["kcal"] == 0
    assert (await client.get(url(ayer), headers=headers)).json()["totals"]["consumed"][
        "kcal"
    ] == 500


async def registered_days_ago(app, account, days: int) -> None:
    """Retrasa el alta de la cuenta: el rango del diario empieza en ella (FR-010)."""
    from sqlalchemy import update

    from mykcal.accounts.models import UserAccount

    async with app.state.sessionmaker() as s:
        await s.execute(
            update(UserAccount)
            .where(UserAccount.id == account.id)
            .values(created_at=datetime.now(UTC) - timedelta(days=days))
        )
        await s.commit()


async def test_objetivo_vigente_por_dia(app, client, user_with_consent, make_target_version):
    """FR-011, US4.3: un día pasado usa el objetivo de entonces y hoy el nuevo."""
    account, headers = await user_with_consent("diary-targets")
    await registered_days_ago(app, account, 20)
    await make_target_version(account, datetime.now(UTC) - timedelta(days=10), kcal=2000)
    await make_target_version(account, datetime.now(UTC) - timedelta(days=2), kcal=1800)
    hace_5 = TODAY - timedelta(days=5)
    assert (await client.get(url(hace_5), headers=headers)).json()["target"]["kcal"] == 2000
    assert (await client.get(url(TODAY), headers=headers)).json()["target"]["kcal"] == 1800
    assert (await client.get(url(TODAY), headers=headers)).json()["remaining"]["kcal"] == 1800


async def test_dia_anterior_al_primer_objetivo_usa_el_primero(
    app, client, user_with_consent, make_target_version
):
    account, headers = await user_with_consent("diary-first")
    await registered_days_ago(app, account, 20)
    await make_target_version(account, datetime.now(UTC) - timedelta(days=1), kcal=1700)
    resp = await client.get(url(TODAY - timedelta(days=3)), headers=headers)
    assert resp.json()["target"]["kcal"] == 1700


async def test_sin_objetivo_404(client, user_with_consent):
    _, headers = await user_with_consent("diary-notarget")
    resp = await client.get(url(TODAY), headers=headers)
    assert resp.status_code == 404
    assert resp.json()["code"] == "TARGET_NOT_FOUND"


@pytest.mark.parametrize(
    "query", ["", "?utc_offset_min=841", "?utc_offset_min=-841", "?utc_offset_min=x"]
)
async def test_utc_offset_min_obligatorio_y_acotado(client, user, query):
    _, headers = user
    resp = await client.get(f"/v1/diary/days/{TODAY.isoformat()}{query}", headers=headers)
    assert resp.status_code == 400
    assert resp.json()["code"] == "VALIDATION_ERROR"


async def test_fecha_mal_formada_400(client, user):
    _, headers = user
    resp = await client.get("/v1/diary/days/no-es-fecha?utc_offset_min=0", headers=headers)
    assert resp.status_code == 400


# --- T058: rango de fechas (FR-010) ------------------------------------------------------------


async def test_fecha_fuera_de_rango_400(client, user):
    _, headers = user  # alta: ahora
    for day in (TODAY - timedelta(days=3), TODAY + timedelta(days=3)):
        resp = await client.get(url(day), headers=headers)
        assert resp.status_code == 400, day
        assert resp.json()["code"] == "DIARY_DATE_OUT_OF_RANGE"


async def test_fechas_de_margen_permitidas(client, user):
    _, headers = user
    for day in (TODAY - timedelta(days=1), TODAY, TODAY + timedelta(days=1)):
        assert (await client.get(url(day), headers=headers)).status_code == 200, day


async def test_post_con_fecha_fuera_de_rango_400(client, user, make_food):
    _, headers = user
    food = await make_food("Pan")
    for day in (TODAY - timedelta(days=3), TODAY + timedelta(days=3)):
        resp = await client.post(
            "/v1/diary/entries?utc_offset_min=0",
            json={"date": day.isoformat(), "meal": "lunch", "food_id": str(food), "quantity": 10},
            headers=headers,
        )
        assert resp.status_code == 400, day
        assert resp.json()["code"] == "DIARY_DATE_OUT_OF_RANGE"


async def test_entrada_de_un_dia_pasado_no_aparece_en_hoy(client, user, make_food):
    _, headers = user
    food = await make_food("Pan", kcal=100)
    ayer = TODAY - timedelta(days=1)
    resp = await client.post(
        "/v1/diary/entries?utc_offset_min=0",
        json={"date": ayer.isoformat(), "meal": "dinner", "food_id": str(food), "quantity": 100},
        headers=headers,
    )
    assert resp.status_code == 201 and resp.json()["totals"]["consumed"]["kcal"] == 100
    hoy = (await client.get(url(TODAY), headers=headers)).json()
    assert hoy["totals"]["consumed"]["kcal"] == 0
