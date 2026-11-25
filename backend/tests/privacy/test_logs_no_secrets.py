"""T023: ni el token ni el sub ni Authorization aparecen en los logs."""

import json

import pytest
from sqlalchemy import text

pytestmark = pytest.mark.privacy


def _content(out: str) -> str:
    """El texto de los registros sin ids, marcas de tiempo ni duraciones.

    Las cifras sueltas ("317") pueden aparecer por azar dentro de un UUID o un reloj; lo que
    importa es que no aparezcan en el contenido de los eventos.
    """
    noise = {"user_id", "request_id", "timestamp", "duration_ms"}
    kept = []
    for line in out.splitlines():
        event = json.loads(line)
        kept.append(json.dumps({k: v for k, v in event.items() if k not in noise}))
    return "\n".join(kept)


def _lines(capsys) -> list[str]:
    return [line for line in capsys.readouterr().out.splitlines() if line.strip()]


async def test_logs_sin_secretos(client, zitadel, make_account, capsys):
    sub = "sub-super-secreto-123"
    await make_account(sub)
    token = zitadel.token(sub)
    await client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    await client.get("/v1/me", headers={"Authorization": f"Bearer {token}x"})
    await client.get("/v1/me")
    out = "\n".join(_lines(capsys))
    assert out, "debería haber registros de acceso"
    assert token not in out
    assert sub not in out
    assert "Authorization" not in out and "Bearer" not in out
    for line in out.splitlines():
        json.loads(line)


async def test_error_500_queda_registrado(app, client, zitadel, make_account, capsys):
    await make_account("u1")

    async def boom(*a, **k):
        raise RuntimeError("secreto-interno")

    app.state.oidc.verify = boom
    resp = await client.get("/v1/me", headers=zitadel.headers("u1"))
    assert resp.status_code == 500
    out = "\n".join(_lines(capsys))
    assert '"unhandled_error"' in out and "RuntimeError" in out
    assert "secreto-interno" not in out


async def test_caida_de_base_de_datos_se_registra(app, client, zitadel, capsys):
    await app.state.engine.dispose()
    original = app.state.sessionmaker

    class Broken:
        def __call__(self):
            raise ConnectionError("db caída")

    app.state.sessionmaker = Broken()
    resp = await client.get("/v1/health")
    app.state.sessionmaker = original
    assert resp.status_code == 503
    assert "unhandled_error" in "\n".join(_lines(capsys))
    _ = text


async def test_logs_sin_valores_de_salud(
    client, zitadel, make_account, grant_consent, profile_body, capsys
):
    """Principio X: edad, altura, peso y objetivo no aparecen en los logs."""
    await grant_consent(await make_account("u-salud"))
    h = zitadel.headers("u-salud")
    capsys.readouterr()
    body = profile_body(age=47, height_cm=193, weight_kg=87.3, goal="lose_fat")
    resp = await client.put("/v1/profile", json=body, headers=h)
    values = resp.json()["target"]["values"]
    await client.put("/v1/target", json=values | {"kcal": 1999}, headers=h)
    await client.put("/v1/profile", json=profile_body(age=7), headers=h)  # inválido
    out = "\n".join(_lines(capsys))
    events = [json.loads(line) for line in out.splitlines()]
    names = {e.get("event") for e in events}
    assert {"profile_saved", "target_saved"} <= names
    for e in events:
        for key in ("age", "height_cm", "weight_kg", "kcal", "sex", "goal", "weight", "values"):
            assert key not in e, (key, e)
    for needle in ("87.3", "193", "1999", "lose_fat", '"age"', "weight_kg"):
        assert needle not in out, needle
    assert any(e.get("source") == "manual" for e in events if e.get("event") == "target_saved")


async def test_logs_de_alimentos_sin_consultas_codigos_ni_nombres(
    app, client, user_with_consent, tmp_path, capsys
):
    """Principio X (R15): lo que se busca, se escanea o se crea no queda en los registros."""
    from decimal import Decimal

    import httpx
    from sqlalchemy import text as sql

    from mykcal.foods.ciqual import write_seed
    from mykcal.foods.load_generic import import_generic
    from mykcal.foods.nutrients import NUTRIENTS

    code = "8410000000016"
    off_calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        off_calls.append(request)
        return httpx.Response(
            200,
            json={
                "status": 1,
                "code": code,
                "product": {
                    "product_name": "Yogur secretísimo",
                    "brands": "MarcaPrivada",
                    "nutriments": {
                        "energy-kcal_100g": 61.7,
                        "proteins_100g": 3.5,
                        "carbohydrates_100g": 4.7,
                        "fat_100g": 3.3,
                    },
                },
            },
        )

    app.state.off_transport = httpx.MockTransport(handler)
    row = {"ciqual_code": "1", "name": "Alimento de semilla", "synonyms": ""}
    row.update({n: None for n in NUTRIENTS})
    row.update(kcal=Decimal("90"), protein_g=Decimal("1"), carbs_g=Decimal("1"), fat_g=Decimal("1"))
    seed = tmp_path / "seed.csv"
    write_seed(seed, "2025", [row])
    try:
        _, headers = await user_with_consent("u-comida")
        capsys.readouterr()
        await client.get("/v1/foods/search", params={"q": "chorizo"}, headers=headers)
        await client.get("/v1/foods/barcode", params={"code": code}, headers=headers)
        created = await client.post(
            "/v1/foods/custom",
            json={
                "name": "Tarta de la abuela",
                "brand": "Casa Pepita",
                "barcode": "8410000000023",
                "base_unit": "g",
                "basis": "per_100",
                "values": {"kcal": 321, "protein_g": 6.7, "carbs_g": 45.3, "fat_g": 13.9},
            },
            headers=headers,
        )
        food_id = created.json()["food"]["id"]
        await client.delete(f"/v1/foods/custom/{food_id}", headers=headers)
        await import_generic(app.state.sessionmaker, seed)
    finally:
        app.state.off_transport = None
        async with app.state.sessionmaker() as s, s.begin():
            await s.execute(sql("DELETE FROM food WHERE kind IN ('generic', 'packaged')"))
            await s.execute(sql("DELETE FROM food_import"))

    assert off_calls, "el escaneo debía consultar a Open Food Facts simulado"
    out = "\n".join(_lines(capsys))
    events = [json.loads(line) for line in out.splitlines()]
    names = {e.get("event") for e in events}
    assert {"food_search", "barcode_lookup", "custom_food_saved", "custom_food_deleted"} <= names
    assert {"generic_import_done"} <= names
    # Los identificadores y las marcas de tiempo llevan números al azar: se excluyen.
    noisy = {"user_id", "request_id", "timestamp", "duration_ms", "food_id"}
    relevant = json.dumps([{k: v for k, v in e.items() if k not in noisy} for e in events])
    for needle in (
        "chorizo",
        code,
        "8410000000023",
        "Yogur secretísimo",
        "MarcaPrivada",
        "Tarta de la abuela",
        "Casa Pepita",
        "Alimento de semilla",
    ):
        assert needle not in out, needle
    for needle in ("321", "6.7", "45.3", "13.9", "61.7"):
        assert needle not in relevant, needle


async def test_logs_del_diario_sin_alimentos_cantidades_fechas_ni_valores(
    client, user_with_consent, make_target_version, make_food, capsys
):
    """Principio X (R12): qué se come y cuánto no queda en los registros."""
    from datetime import UTC, datetime, timedelta

    account, headers = await user_with_consent("u-diario")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=3))
    food = await make_food("Lentejas estofadas secretas", kcal=123.4)
    day = (datetime.now(UTC) - timedelta(days=1)).date().isoformat()
    q = "?utc_offset_min=0"
    capsys.readouterr()
    created = await client.post(
        f"/v1/diary/entries{q}",
        json={"date": day, "meal": "dinner", "food_id": str(food), "quantity": 317},
        headers=headers,
    )
    entry = created.json()["meals"][3]["entries"][0]["id"]
    await client.patch(f"/v1/diary/entries/{entry}{q}", json={"quantity": 281}, headers=headers)
    await client.delete(f"/v1/diary/entries/{entry}{q}", headers=headers)
    await client.post(f"/v1/diary/entries/{entry}/restore{q}", headers=headers)
    await client.get(f"/v1/diary/days/{day}{q}", headers=headers)
    out = "\n".join(_lines(capsys))
    events = [json.loads(line) for line in out.splitlines()]
    diary = [e for e in events if str(e.get("event", "")).startswith("diary_entry_")]
    assert {e["event"] for e in diary} == {
        "diary_entry_created",
        "diary_entry_updated",
        "diary_entry_deleted",
        "diary_entry_restored",
    }
    for e in diary:
        assert set(e) >= {"user_id", "meal", "duration_ms"}, e
        for key in ("food_name", "quantity", "servings", "date", "entry_date", "values", "kcal"):
            assert key not in e, (key, e)
    content = _content(out)
    for needle in ("Lentejas", "317", "281", "123.4", day):
        assert needle not in content, needle


async def test_logs_de_recientes_y_favoritos_sin_alimentos_ni_cantidades(
    client, user_with_consent, make_target_version, make_food, make_entry, capsys
):
    """Principio X (005, R11): listar no deja evento; marcar y desmarcar solo usuario y duración."""
    from datetime import UTC, datetime, timedelta

    account, headers = await user_with_consent("u-quick")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=3))
    food = await make_food("Fabada asturiana secreta", kcal=177.7)
    await make_entry(account, datetime.now(UTC).date(), food_id=food, quantity=313)
    capsys.readouterr()
    await client.get("/v1/foods/recent", headers=headers)
    await client.get("/v1/foods/favorites", headers=headers)
    await client.put(f"/v1/foods/favorites/{food}", headers=headers)
    await client.delete(f"/v1/foods/favorites/{food}", headers=headers)
    out = "\n".join(_lines(capsys))
    events = [json.loads(line) for line in out.splitlines()]
    quick = [e for e in events if str(e.get("event", "")).startswith("favorite_")]
    assert {e["event"] for e in quick} == {"favorite_added", "favorite_removed"}
    assert not [e for e in events if "recent" in str(e.get("event", ""))]
    content = _content(out)
    for needle in ("Fabada", "313", "177.7", str(food)):
        assert needle not in content, needle


async def test_logs_de_la_copia_sin_alimentos_cantidades_ni_fechas(
    client, user_with_consent, make_target_version, make_food, make_entry, capsys
):
    """Principio X (005, R11): copiar y deshacer registran comidas y número de entradas, no más."""
    from datetime import UTC, datetime, timedelta

    account, headers = await user_with_consent("u-copia")
    await make_target_version(account, datetime.now(UTC) - timedelta(days=3))
    food = await make_food("Cocido madrileño secreto", kcal=143.9)
    today = datetime.now(UTC).date()
    ayer = today - timedelta(days=1)
    await make_entry(account, ayer, "lunch", food_id=food, quantity=377)
    capsys.readouterr()
    body = {
        "source_date": ayer.isoformat(),
        "source_meal": "lunch",
        "target_date": today.isoformat(),
        "target_meal": "dinner",
    }
    copied = await client.post("/v1/diary/copies?utc_offset_min=0", json=body, headers=headers)
    copy_id = copied.json()["copy_id"]
    await client.delete(f"/v1/diary/copies/{copy_id}?utc_offset_min=0", headers=headers)
    await client.get(
        "/v1/diary/copy-sources",
        params={"target_date": today.isoformat(), "target_meal": "dinner"},
        headers=headers,
    )
    out = "\n".join(_lines(capsys))
    events = [json.loads(line) for line in out.splitlines()]
    ours = [e for e in events if str(e.get("event", "")).startswith(("diary_meal", "diary_copy"))]
    assert {e["event"] for e in ours} == {"diary_meal_copied", "diary_copy_undone"}
    content = _content(out)
    for needle in ("Cocido", "377", "143.9", ayer.isoformat(), copy_id, str(food)):
        assert needle not in content, needle


async def test_evento_ai_analysis_no_lleva_foto_respuesta_clave_ni_descripcion(
    client, user_with_consent, ai, capsys
):
    _, h = await user_with_consent("ai-logs")
    key = "AIzaSyClaveParaLogs0123456789"
    await client.put("/v1/ai-key", headers=h, json={"raw_key": key})
    secret_text = "descripcion-privada-xyz"
    ai.response_json = '{"items": [{"name": "Plato-secreto-de-la-ia", "grams": 100}]}'
    for outcome in (
        "success",
        "key_invalid",
        "quota_exceeded",
        "invalid_json",
        "empty_items",
        "timeout",
        "unavailable",
    ):
        ai.analyze_outcome = outcome
        await client.post(
            "/v1/photo-analysis",
            headers=h,
            files={"photo": ("p.jpg", b"\xff\xd8FOTO-SECRETA", "image/jpeg")},
            data={"meal": "lunch", "entry_date": "2026-01-01", "description": secret_text},
        )
    out = capsys.readouterr().out
    events = [json.loads(line) for line in out.splitlines() if line.strip()]
    assert len([e for e in events if e["event"] == "ai_analysis"]) == 7
    for forbidden in (
        key,
        secret_text,
        "FOTO-SECRETA",
        "Plato-secreto-de-la-ia",
        "esto no es json",
    ):
        assert forbidden not in out
    for e in events:
        if e["event"] == "ai_analysis":
            assert set(e) <= {
                "event",
                "level",
                "timestamp",
                "user_id",
                "result",
                "model",
                "duration_ms",
                "request_id",
            }
