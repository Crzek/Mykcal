"""T050 (005): copiar una comida de otro día y deshacerla (FR-005, FR-006, FR-007, SC-003)."""

import json
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import text

from mykcal import clock

NOW = datetime.now(UTC)
TODAY = NOW.date()
YESTERDAY = TODAY - timedelta(days=1)
Q = "?utc_offset_min=0"


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("copy-user")
    await make_target_version(account, NOW - timedelta(days=30))
    return account, headers


def body(
    source_date=YESTERDAY, source_meal="breakfast", target_date=TODAY, target_meal="breakfast"
):
    return {
        "source_date": source_date.isoformat(),
        "source_meal": source_meal,
        "target_date": target_date.isoformat(),
        "target_meal": target_meal,
    }


def meal(day, name):
    return next(m for m in day["meals"] if m["meal"] == name)


async def copy(client, headers, **kw):
    return await client.post(f"/v1/diary/copies{Q}", json=body(**kw), headers=headers)


async def rows(app, user_id, day, meal_name):
    async with app.state.sessionmaker() as s:
        result = await s.execute(
            text(
                "SELECT id, food_name, kcal, quantity, servings, copy_id, deleted_at, created_at "
                "FROM diary_entry WHERE user_id = :u AND entry_date = :d AND meal = :m "
                "ORDER BY created_at, id"
            ),
            {"u": user_id, "d": day, "m": meal_name},
        )
        return result.all()


async def seed_breakfast(account, make_entry, make_food):
    pan = await make_food("Pan", kcal=250)
    leche = await make_food("Leche", kcal=50, base_unit="ml")
    t = NOW - timedelta(days=1)
    await make_entry(account, YESTERDAY, "breakfast", food_id=pan, quantity=60, created_at=t)
    await make_entry(
        account,
        YESTERDAY,
        "breakfast",
        food_id=leche,
        quantity=250,
        created_at=t + timedelta(seconds=1),
    )
    return pan, leche


async def test_copia_a_una_comida_vacia_y_deja_el_origen_intacto(
    app, client, user, make_entry, make_food
):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    before = await rows(app, account.id, YESTERDAY, "breakfast")
    resp = await copy(client, headers)
    assert resp.status_code == 201, resp.text
    result = resp.json()
    entries = meal(result["day"], "breakfast")["entries"]
    assert [e["food_name"] for e in entries] == ["Pan", "Leche"]  # mismo orden
    assert [e["quantity"] for e in entries] == [60, 250]
    assert [e["id"] for e in entries] == result["entry_ids"]
    assert result["day"]["totals"]["consumed"]["kcal"] == 275  # 150 + 125
    # SC-003: ayer queda idéntico fila a fila
    assert await rows(app, account.id, YESTERDAY, "breakfast") == before
    copied = await rows(app, account.id, TODAY, "breakfast")
    assert {str(r.copy_id) for r in copied} == {result["copy_id"]}
    assert all(r.created_at > before[0].created_at for r in copied)


async def test_se_suma_a_las_entradas_existentes(client, user, make_entry, make_food):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    await make_entry(account, TODAY, "breakfast", quantity=100, kcal=100, name="Ya estaba")
    resp = await copy(client, headers)
    names = [e["food_name"] for e in meal(resp.json()["day"], "breakfast")["entries"]]
    assert names == ["Ya estaba", "Pan", "Leche"]


async def test_se_puede_copiar_a_otra_comida(client, user, make_entry, make_food):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    resp = await copy(client, headers, target_meal="dinner")
    assert resp.status_code == 201
    assert len(meal(resp.json()["day"], "dinner")["entries"]) == 2
    assert meal(resp.json()["day"], "breakfast")["entries"] == []


async def test_fechas_fuera_de_rango_son_400(client, user, make_entry, make_food):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    for source in (
        TODAY,  # igual al destino
        TODAY + timedelta(days=1),  # posterior
        TODAY - timedelta(days=15),  # fuera de los 14 días
    ):
        resp = await copy(client, headers, source_date=source)
        assert resp.status_code == 400, source
        assert resp.json()["code"] == "DIARY_DATE_OUT_OF_RANGE"
    resp = await copy(client, headers, target_date=TODAY + timedelta(days=5))
    assert resp.status_code == 400 and resp.json()["code"] == "DIARY_DATE_OUT_OF_RANGE"


async def test_el_dia_14_atras_si_se_puede_copiar(client, user, make_entry):
    account, headers = user
    day = TODAY - timedelta(days=14)
    await make_entry(account, day, "lunch", quantity=100, kcal=100)
    resp = await copy(client, headers, source_date=day, source_meal="lunch", target_meal="lunch")
    assert resp.status_code == 201


async def test_origen_sin_entradas_es_400(client, user, make_entry):
    account, headers = user
    await make_entry(account, YESTERDAY, "breakfast", deleted_at=NOW)  # borrada: no cuenta
    resp = await copy(client, headers)
    assert resp.status_code == 400 and resp.json()["code"] == "COPY_SOURCE_EMPTY"
    resp = await copy(client, headers, source_meal="dinner")
    assert resp.status_code == 400 and resp.json()["code"] == "COPY_SOURCE_EMPTY"


async def test_sin_objetivo_no_copia_nada(app, client, user_with_consent, make_entry):
    account, headers = await user_with_consent("copy-sin-objetivo")
    await make_entry(account, YESTERDAY, "breakfast")
    resp = await copy(client, headers)
    assert resp.status_code == 404 and resp.json()["code"] == "TARGET_NOT_FOUND"
    assert await rows(app, account.id, TODAY, "breakfast") == []


async def set_food(app, food_id, **cols):
    sets = ", ".join(f"{k} = :{k}" for k in cols)
    async with app.state.engine.begin() as conn:
        await conn.execute(text(f"UPDATE food SET {sets} WHERE id = :id"), {"id": food_id, **cols})


async def test_v2_usa_los_valores_actuales_del_alimento(app, client, user, make_entry, make_food):
    account, headers = user
    food = await make_food("Mi bizcocho", kind="custom", owner=account, kcal=300, serving_size=50)
    await make_entry(account, YESTERDAY, "breakfast", food_id=food, quantity=100, servings=2)
    await set_food(app, food, kcal=350, name="Bizcocho casero")
    entry = meal((await copy(client, headers)).json()["day"], "breakfast")["entries"][0]
    assert entry["food_name"] == "Bizcocho casero" and entry["per_100"]["kcal"] == 350
    assert entry["quantity"] == 100 and entry["servings"] == 2 and entry["values"]["kcal"] == 350


async def test_v3_racion_distinta_pierde_las_raciones(app, client, user, make_entry, make_food):
    account, headers = user
    food = await make_food("Mi bizcocho", kind="custom", owner=account, kcal=300, serving_size=50)
    await make_entry(account, YESTERDAY, "breakfast", food_id=food, quantity=100, servings=2)
    await set_food(app, food, serving_size=80)
    entry = meal((await copy(client, headers)).json()["day"], "breakfast")["entries"][0]
    assert entry["quantity"] == 100 and entry["servings"] is None and entry["serving_size"] == 80


async def test_v4_alimento_borrado_conserva_los_valores_de_la_entrada(
    app, client, user, make_entry, make_food
):
    account, headers = user
    food = await make_food("Mi bizcocho", kind="custom", owner=account, kcal=300, serving_size=50)
    await make_entry(account, YESTERDAY, "breakfast", food_id=food, quantity=100, servings=2)
    await set_food(app, food, deleted_at=NOW)
    entry = meal((await copy(client, headers)).json()["day"], "breakfast")["entries"][0]
    assert entry["food_name"] == "Mi bizcocho" and entry["per_100"]["kcal"] == 300
    assert entry["quantity"] == 100 and entry["servings"] == 2


async def test_v5_generico_archivado_conserva_los_valores_de_la_entrada(
    app, client, user, make_entry, make_food
):
    account, headers = user
    food = await make_food("Arroz", kcal=130)
    await make_entry(account, YESTERDAY, "breakfast", food_id=food, quantity=200)
    await set_food(app, food, archived_at=NOW, kcal=500)
    entry = meal((await copy(client, headers)).json()["day"], "breakfast")["entries"][0]
    assert entry["per_100"]["kcal"] == 130 and entry["values"]["kcal"] == 260


async def undo(client, headers, copy_id):
    return await client.delete(f"/v1/diary/copies/{copy_id}{Q}", headers=headers)


async def test_deshacer_borra_solo_las_copiadas(client, user, make_entry, make_food):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    await make_entry(account, TODAY, "breakfast", quantity=100, kcal=100, name="Ya estaba")
    result = (await copy(client, headers)).json()
    await make_entry(account, TODAY, "breakfast", quantity=10, kcal=10, name="Añadida después")
    resp = await undo(client, headers, result["copy_id"])
    assert resp.status_code == 200, resp.text
    names = [e["food_name"] for e in meal(resp.json(), "breakfast")["entries"]]
    assert names == ["Ya estaba", "Añadida después"]
    # El origen de ayer sigue completo
    ayer = (await client.get(f"/v1/diary/days/{YESTERDAY.isoformat()}{Q}", headers=headers)).json()
    assert len(meal(ayer, "breakfast")["entries"]) == 2


async def test_deshacer_a_los_60_s_si_y_a_los_61_no(
    client, user, make_entry, make_food, monkeypatch
):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    t0 = datetime.now(UTC)
    monkeypatch.setattr(clock, "utcnow", lambda: t0)
    first = (await copy(client, headers)).json()
    monkeypatch.setattr(clock, "utcnow", lambda: t0 + timedelta(seconds=60))
    assert (await undo(client, headers, first["copy_id"])).status_code == 200
    second = (await copy(client, headers)).json()  # t0 + 60 s
    monkeypatch.setattr(clock, "utcnow", lambda: t0 + timedelta(seconds=60 + 61))
    late = await undo(client, headers, second["copy_id"])
    assert late.status_code == 404 and late.json()["code"] == "COPY_NOT_FOUND"


async def test_deshacer_dos_veces_o_con_un_id_inexistente_es_404(
    client, user, make_entry, make_food
):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    result = (await copy(client, headers)).json()
    assert (await undo(client, headers, result["copy_id"])).status_code == 200
    again = await undo(client, headers, result["copy_id"])
    assert again.status_code == 404 and again.json()["code"] == "COPY_NOT_FOUND"
    nobody = await undo(client, headers, uuid.uuid4())
    assert nobody.status_code == 404 and nobody.json()["code"] == "COPY_NOT_FOUND"


async def test_copy_sources_ventana_orden_y_totales(client, user, make_entry, make_food):
    account, headers = user
    await make_entry(
        account, TODAY - timedelta(days=1), "breakfast", quantity=100, kcal=200, name="A"
    )
    await make_entry(account, TODAY - timedelta(days=1), "dinner", quantity=50, kcal=300, name="B")
    await make_entry(account, TODAY - timedelta(days=1), "dinner", quantity=100, kcal=100, name="C")
    await make_entry(account, TODAY - timedelta(days=5), "lunch", quantity=100, kcal=400, name="D")
    await make_entry(account, TODAY - timedelta(days=14), "snacks", quantity=100, kcal=50, name="E")
    await make_entry(account, TODAY - timedelta(days=15), "snacks", name="Fuera")
    await make_entry(account, TODAY, "snacks", name="Hoy")  # el propio día no cuenta
    await make_entry(account, TODAY - timedelta(days=2), "lunch", deleted_at=NOW, name="Borrada")
    resp = await client.get(
        "/v1/diary/copy-sources",
        params={"target_date": TODAY.isoformat(), "target_meal": "dinner"},
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    days = resp.json()["days"]
    assert [d["date"] for d in days] == [
        (TODAY - timedelta(days=n)).isoformat() for n in (1, 5, 14)
    ]
    ayer = days[0]["meals"]
    assert [m["meal"] for m in ayer] == ["dinner", "breakfast"]  # la del destino primero
    assert ayer[0]["kcal"] == 250 and [e["food_name"] for e in ayer[0]["entries"]] == ["B", "C"]
    assert ayer[0]["entries"][0]["kcal"] == 150 and ayer[0]["values_changed"] is False
    assert "Fuera" not in resp.text and "Hoy" not in resp.text and "Borrada" not in resp.text


async def test_copy_sources_marca_valores_cambiados(app, client, user, make_entry, make_food):
    account, headers = user
    food = await make_food("Mi bizcocho", kind="custom", owner=account, kcal=300)
    gone = await make_food("Borrado", kind="custom", owner=account, kcal=100)
    await make_entry(account, YESTERDAY, "breakfast", food_id=food)
    await make_entry(account, YESTERDAY, "lunch", food_id=gone)
    await set_food(app, food, kcal=350)
    await set_food(app, gone, kcal=500, deleted_at=NOW)  # no disponible: no cuenta como cambio
    resp = await client.get(
        "/v1/diary/copy-sources",
        params={"target_date": TODAY.isoformat(), "target_meal": "snacks"},
        headers=headers,
    )
    flags = {m["meal"]: m["values_changed"] for m in resp.json()["days"][0]["meals"]}
    assert flags == {"breakfast": True, "lunch": False}


async def test_copy_sources_con_fecha_destino_fuera_de_rango(client, user):
    _, headers = user
    resp = await client.get(
        "/v1/diary/copy-sources",
        params={"target_date": (TODAY + timedelta(days=9)).isoformat(), "target_meal": "lunch"},
        headers=headers,
    )
    assert resp.status_code == 400 and resp.json()["code"] == "DIARY_DATE_OUT_OF_RANGE"


async def test_copy_sources_sin_entradas_devuelve_lista_vacia(client, user):
    _, headers = user
    resp = await client.get(
        "/v1/diary/copy-sources",
        params={"target_date": TODAY.isoformat(), "target_meal": "lunch"},
        headers=headers,
    )
    assert resp.status_code == 200 and resp.json() == {"days": []}


async def test_eventos_de_copia_sin_alimento_cantidad_ni_fecha(
    client, user, make_entry, make_food, capsys
):
    account, headers = user
    await seed_breakfast(account, make_entry, make_food)
    capsys.readouterr()
    result = (await copy(client, headers)).json()
    await undo(client, headers, result["copy_id"])
    out = capsys.readouterr().out
    events = [json.loads(line) for line in out.splitlines() if line.startswith("{")]
    ours = [
        e
        for e in events
        if str(e.get("event", "")).startswith("diary_meal_copied")
        or str(e.get("event", "")) == "diary_copy_undone"
    ]
    assert {e["event"] for e in ours} == {"diary_meal_copied", "diary_copy_undone"}
    copied = next(e for e in ours if e["event"] == "diary_meal_copied")
    assert copied["entries_count"] == 2 and {"user_id", "duration_ms"} <= set(copied)
    content = json.dumps(
        [
            {k: v for k, v in e.items() if k not in {"user_id", "request_id", "timestamp"}}
            for e in ours
        ]
    )
    for needle in ("Pan", "Leche", YESTERDAY.isoformat(), result["copy_id"]):
        assert needle not in content, needle
