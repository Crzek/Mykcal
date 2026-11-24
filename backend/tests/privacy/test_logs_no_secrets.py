"""T023: ni el token ni el sub ni Authorization aparecen en los logs."""

import json

import pytest
from sqlalchemy import text

pytestmark = pytest.mark.privacy


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
