"""T036 (004): POST /v1/diary/entries (FR-002–FR-004). Editar y borrar, en T048."""

from datetime import UTC, datetime, timedelta

import pytest

TODAY = datetime.now(UTC).date()


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("diary-entries")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=30))
    return account, headers


def post(client, headers, *, offset=0, **body):
    payload = {"date": TODAY.isoformat(), "meal": "breakfast", **body}
    return client.post(f"/v1/diary/entries?utc_offset_min={offset}", json=payload, headers=headers)


def meal(day, name):
    return next(m for m in day["meals"] if m["meal"] == name)


async def test_150_g_de_200_kcal_son_300_kcal(client, user, make_food):
    _, headers = user
    food = await make_food("Pan", kcal=200)
    resp = await post(client, headers, food_id=str(food), quantity=150)
    assert resp.status_code == 201
    day = resp.json()
    entry = meal(day, "breakfast")["entries"][0]
    assert entry["values"]["kcal"] == 300 and entry["quantity"] == 150 and entry["servings"] is None
    assert day["totals"]["consumed"]["kcal"] == 300
    assert day["remaining"]["kcal"] == 1700


async def test_raciones_se_guardan_como_gramos(client, user, make_food):
    """US2.2: 2 raciones de un envasado de 30 g son 60 g."""
    _, headers = user
    food = await make_food("Galletas", kind="packaged", barcode="8410000000009", serving_size=30)
    resp = await post(client, headers, food_id=str(food), servings=2)
    assert resp.status_code == 201
    entry = meal(resp.json(), "breakfast")["entries"][0]
    assert entry["quantity"] == 60.0 and entry["servings"] == 2.0 and entry["serving_size"] == 30.0


async def test_copia_el_alimento_tal_cual_incluidos_los_sin_dato(client, user, make_food):
    _, headers = user
    food = await make_food(
        "Yogur",
        kind="packaged",
        barcode="8410000000016",
        brand="Marca",
        fiber_g=1.5,
        serving_size=125,
        base_unit="g",
    )
    resp = await post(client, headers, food_id=str(food), quantity=125, meal="snacks")
    entry = meal(resp.json(), "snacks")["entries"][0]
    assert (entry["food_name"], entry["food_brand"], entry["food_kind"]) == (
        "Yogur",
        "Marca",
        "packaged",
    )
    assert entry["food_id"] == str(food) and entry["base_unit"] == "g"
    per_100 = entry["per_100"]
    assert per_100["kcal"] == 100 and per_100["fiber_g"] == 1.5
    assert per_100["sodium_mg"] is None  # sin dato, no 0 (FR-003)
    assert entry["values"]["sodium_mg"] is None
    assert "sodium_mg" in entry["incomplete"] and "fiber_g" not in entry["incomplete"]


async def test_el_mismo_alimento_dos_veces_son_dos_entradas(client, user, make_food):
    """Clarificación 1: nunca se fusionan."""
    _, headers = user
    food = await make_food("Pan", kcal=200)
    await post(client, headers, food_id=str(food), quantity=100)
    resp = await post(client, headers, food_id=str(food), quantity=50)
    entries = meal(resp.json(), "breakfast")["entries"]
    assert [e["quantity"] for e in entries] == [100, 50]
    assert meal(resp.json(), "breakfast")["totals"]["consumed"]["kcal"] == 300


@pytest.mark.parametrize(
    ("extra", "fields"),
    [
        ({"quantity": 0}, ["quantity"]),
        ({"quantity": -5}, ["quantity"]),
        ({"quantity": 10000.1}, ["quantity"]),
        ({"servings": 2}, ["servings"]),  # el alimento no tiene ración
        ({"quantity": 100, "servings": 2}, ["quantity", "servings"]),
        ({}, ["quantity", "servings"]),
    ],
)
async def test_cantidades_no_validas(client, user, make_food, extra, fields):
    _, headers = user
    food = await make_food("Pan")
    resp = await post(client, headers, food_id=str(food), **extra)
    assert resp.status_code == 400
    body = resp.json()
    assert body["code"] == "VALIDATION_ERROR"
    assert set(body["fields"]) == set(fields)


async def test_no_se_pueden_enviar_valores_nutricionales(client, user, make_food):
    """FR-003: los valores salen de la base, nunca de la petición."""
    _, headers = user
    food = await make_food("Pan")
    resp = await post(client, headers, food_id=str(food), quantity=100, kcal=1)
    assert resp.status_code == 400
    assert resp.json()["fields"] == ["kcal"]


async def test_comida_no_valida(client, user, make_food):
    _, headers = user
    food = await make_food("Pan")
    resp = await post(client, headers, food_id=str(food), quantity=100, meal="brunch")
    assert resp.status_code == 400


async def test_alimentos_no_disponibles_dan_food_not_found(
    client, user, user_with_consent, make_food
):
    account, headers = user
    otro, _ = await user_with_consent("diary-otro")
    ajeno = await make_food("Tarta ajena", kind="custom", owner=otro)
    borrado = await make_food(
        "Tarta borrada", kind="custom", owner=account, deleted_at=datetime.now(UTC)
    )
    archivado = await make_food("Alimento archivado", archived_at=datetime.now(UTC))
    import uuid

    for food_id in (ajeno, borrado, archivado, uuid.uuid4()):
        resp = await post(client, headers, food_id=str(food_id), quantity=100)
        assert resp.status_code == 404, food_id
        assert resp.json()["code"] == "FOOD_NOT_FOUND"


async def test_un_personalizado_propio_se_puede_registrar(client, user, make_food):
    account, headers = user
    food = await make_food("Mi tarta", kind="custom", owner=account, kcal=320)
    resp = await post(client, headers, food_id=str(food), quantity=100)
    assert resp.status_code == 201
    assert meal(resp.json(), "breakfast")["entries"][0]["food_kind"] == "custom"


async def test_la_respuesta_es_el_dia_de_la_fecha_enviada(client, user, make_food):
    _, headers = user
    ayer = TODAY - timedelta(days=1)
    food = await make_food("Pan", kcal=100)
    resp = await post(client, headers, food_id=str(food), quantity=100, date=ayer.isoformat())
    assert resp.json()["date"] == ayer.isoformat()
    hoy = await client.get(f"/v1/diary/days/{TODAY.isoformat()}?utc_offset_min=0", headers=headers)
    assert hoy.json()["totals"]["consumed"]["kcal"] == 0


async def test_sin_objetivo_404(client, user_with_consent, make_food):
    _, headers = await user_with_consent("diary-sin-objetivo")
    food = await make_food("Pan")
    resp = await post(client, headers, food_id=str(food), quantity=100)
    assert resp.status_code == 404
    assert resp.json()["code"] == "TARGET_NOT_FOUND"


# --- T048: editar, borrar y restaurar ---------------------------------------------------------

from mykcal import clock  # noqa: E402


def q(offset=0):
    return f"?utc_offset_min={offset}"


async def entry_of(client, headers, meal_name="breakfast", date=None):
    day = await client.get(f"/v1/diary/days/{(date or TODAY).isoformat()}{q()}", headers=headers)
    return meal(day.json(), meal_name)["entries"]


async def test_patch_cantidad_recalcula_con_la_copia(client, user, make_entry):
    """Q7: el alimento cambió su ración después; la entrada conserva la suya de 30 g."""
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=60, servings=2, kcal=200, serving_size=30)
    resp = await client.patch(
        f"/v1/diary/entries/{entry}{q()}", json={"servings": 3}, headers=headers
    )
    assert resp.status_code == 200
    e = meal(resp.json(), "breakfast")["entries"][0]
    assert (e["quantity"], e["servings"], e["serving_size"]) == (90, 3, 30)
    assert e["values"]["kcal"] == 180


async def test_patch_quantity_pone_raciones_a_null_q6(client, user, make_entry):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=60, servings=2, kcal=100, serving_size=30)
    resp = await client.patch(
        f"/v1/diary/entries/{entry}{q()}", json={"quantity": 45}, headers=headers
    )
    e = meal(resp.json(), "breakfast")["entries"][0]
    assert e["quantity"] == 45 and e["servings"] is None


async def test_patch_raciones_en_entrada_registrada_en_g(client, user, make_entry):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100, kcal=100, serving_size=30)
    resp = await client.patch(
        f"/v1/diary/entries/{entry}{q()}", json={"servings": 2}, headers=headers
    )
    e = meal(resp.json(), "breakfast")["entries"][0]
    assert (e["quantity"], e["servings"]) == (60, 2)


async def test_patch_raciones_sin_tamano_de_racion(client, user, make_entry):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100, kcal=100)
    resp = await client.patch(
        f"/v1/diary/entries/{entry}{q()}", json={"servings": 2}, headers=headers
    )
    assert resp.status_code == 400 and resp.json()["fields"] == ["servings"]


async def test_patch_mover_de_comida_cambia_los_totales_m2(client, user, make_entry):
    account, headers = user
    entry = await make_entry(account, TODAY, "breakfast", quantity=100, kcal=300)
    resp = await client.patch(
        f"/v1/diary/entries/{entry}{q()}", json={"meal": "dinner"}, headers=headers
    )
    day = resp.json()
    assert meal(day, "breakfast")["entries"] == []
    assert meal(day, "breakfast")["totals"]["consumed"]["kcal"] == 0
    assert meal(day, "dinner")["totals"]["consumed"]["kcal"] == 300
    assert day["totals"]["consumed"]["kcal"] == 300


@pytest.mark.parametrize(
    "body",
    [{}, {"date": "2026-01-01"}, {"quantity": 10, "servings": 1}, {"quantity": 0}, {"meal": "x"}],
)
async def test_patch_no_valido(client, user, make_entry, body):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100, kcal=100, serving_size=30)
    resp = await client.patch(f"/v1/diary/entries/{entry}{q()}", json=body, headers=headers)
    assert resp.status_code == 400


async def test_delete_y_restore_conservan_los_valores(client, user, make_entry, make_food):
    account, headers = user
    food = await make_food("Pan", kcal=200)
    entry = await make_entry(account, TODAY, food_id=food, quantity=100)
    deleted = await client.delete(f"/v1/diary/entries/{entry}{q()}", headers=headers)
    assert deleted.status_code == 200
    assert meal(deleted.json(), "breakfast")["entries"] == []
    assert deleted.json()["totals"]["consumed"]["kcal"] == 0
    # El alimento cambia mientras tanto: la entrada restaurada no.
    from sqlalchemy import update

    from mykcal.foods.models import Food

    async with client._transport.app.state.sessionmaker() as s:  # noqa: SLF001
        await s.execute(update(Food).where(Food.id == food).values(kcal=1))
        await s.commit()
    restored = await client.post(f"/v1/diary/entries/{entry}/restore{q()}", headers=headers)
    assert restored.status_code == 200
    e = meal(restored.json(), "breakfast")["entries"][0]
    assert e["values"]["kcal"] == 200


async def test_restore_pasados_60_s_es_404(client, user, make_entry, monkeypatch):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100)
    t0 = datetime.now(UTC)
    monkeypatch.setattr(clock, "utcnow", lambda: t0)
    assert (
        await client.delete(f"/v1/diary/entries/{entry}{q()}", headers=headers)
    ).status_code == 200
    monkeypatch.setattr(clock, "utcnow", lambda: t0 + timedelta(seconds=61))
    resp = await client.post(f"/v1/diary/entries/{entry}/restore{q()}", headers=headers)
    assert resp.status_code == 404 and resp.json()["code"] == "ENTRY_NOT_FOUND"


async def test_restore_a_los_60_s_funciona(client, user, make_entry, monkeypatch):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100)
    t0 = datetime.now(UTC)
    monkeypatch.setattr(clock, "utcnow", lambda: t0)
    await client.delete(f"/v1/diary/entries/{entry}{q()}", headers=headers)
    monkeypatch.setattr(clock, "utcnow", lambda: t0 + timedelta(seconds=60))
    resp = await client.post(f"/v1/diary/entries/{entry}/restore{q()}", headers=headers)
    assert resp.status_code == 200


async def test_restore_de_una_entrada_no_borrada_es_404(client, user, make_entry):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100)
    resp = await client.post(f"/v1/diary/entries/{entry}/restore{q()}", headers=headers)
    assert resp.status_code == 404 and resp.json()["code"] == "ENTRY_NOT_FOUND"


async def test_entrada_borrada_o_inexistente_no_se_edita_ni_se_borra(client, user, make_entry):
    account, headers = user
    entry = await make_entry(account, TODAY, quantity=100)
    await client.delete(f"/v1/diary/entries/{entry}{q()}", headers=headers)
    for call in (
        client.patch(f"/v1/diary/entries/{entry}{q()}", json={"quantity": 5}, headers=headers),
        client.delete(f"/v1/diary/entries/{entry}{q()}", headers=headers),
    ):
        resp = await call
        assert resp.status_code == 404 and resp.json()["code"] == "ENTRY_NOT_FOUND"
