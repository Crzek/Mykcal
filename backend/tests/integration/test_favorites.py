"""T035 (005): favoritos (FR-003, FR-004, FR-010, research R8)."""

import json
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import text

TODAY = datetime.now(UTC).date()
NOW = datetime.now(UTC)


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("fav-user")
    await make_target_version(account, NOW - timedelta(days=30))
    return account, headers


async def favorites(client, headers):
    resp = await client.get("/v1/foods/favorites", headers=headers)
    assert resp.status_code == 200, resp.text
    return resp.json()["items"]


async def count(app, user_id):
    async with app.state.sessionmaker() as s:
        return (
            await s.execute(
                text("SELECT count(*) FROM favorite_food WHERE user_id = :u"), {"u": user_id}
            )
        ).scalar_one()


async def test_put_dos_veces_deja_un_favorito_y_responde_204_las_dos(app, client, user, make_food):
    account, headers = user
    food = await make_food("Plátano")
    for _ in range(2):
        assert (await client.put(f"/v1/foods/favorites/{food}", headers=headers)).status_code == 204
    assert await count(app, account.id) == 1


async def test_delete_de_uno_que_no_era_favorito_responde_204(client, user, make_food):
    _, headers = user
    food = await make_food("Plátano")
    assert (await client.delete(f"/v1/foods/favorites/{food}", headers=headers)).status_code == 204
    await client.put(f"/v1/foods/favorites/{food}", headers=headers)
    await client.delete(f"/v1/foods/favorites/{food}", headers=headers)
    assert await favorites(client, headers) == []


async def test_put_de_un_alimento_no_disponible_es_404(client, user, make_food, make_account):
    account, headers = user
    otro = await make_account("fav-otro")
    ajeno = await make_food("Tarta de otro", kind="custom", owner=otro)
    borrado = await make_food("Mío borrado", kind="custom", owner=account, deleted_at=NOW)
    archivado = await make_food("Genérico archivado", archived_at=NOW)
    for food_id in (ajeno, borrado, archivado, "00000000-0000-4000-8000-000000000000"):
        resp = await client.put(f"/v1/foods/favorites/{food_id}", headers=headers)
        assert resp.status_code == 404, food_id
        assert resp.json()["code"] == "FOOD_NOT_FOUND"


async def test_orden_por_ultimo_uso_y_los_nunca_usados_al_final_por_nombre(
    client, user, make_food, make_entry, make_favorite
):
    account, headers = user
    viejo = await make_food("Yogur")
    nuevo = await make_food("Avena")
    zumo = await make_food("Zumo")
    aceite = await make_food("Ácido láctico")
    await make_entry(account, TODAY, food_id=viejo, created_at=NOW - timedelta(days=2))
    await make_entry(account, TODAY, food_id=nuevo, created_at=NOW - timedelta(hours=1))
    for food in (viejo, nuevo, zumo, aceite):
        await make_favorite(account, food)
    names = [i["food"]["name"] for i in await favorites(client, headers)]
    assert names == ["Avena", "Yogur", "Ácido láctico", "Zumo"]


async def test_un_personalizado_borrado_deja_de_listarse(client, user, make_food, make_favorite):
    account, headers = user
    food = await make_food("Mi tarta", kind="custom", owner=account)
    await make_favorite(account, food)
    assert len(await favorites(client, headers)) == 1
    resp = await client.delete(f"/v1/foods/custom/{food}", headers=headers)
    assert resp.status_code == 204
    assert await favorites(client, headers) == []


async def test_cantidad_sugerida_de_un_favorito_sin_uso(client, user, make_food, make_favorite):
    """FR-004: 1 ración si el alimento la tiene; si no, 100 g/ml."""
    account, headers = user
    con = await make_food("Galletas", kind="packaged", barcode="8410000000009", serving_size=30)
    sin = await make_food("Leche", base_unit="ml")
    for food in (con, sin):
        await make_favorite(account, food)
    by_name = {i["food"]["name"]: i for i in await favorites(client, headers)}
    assert (
        by_name["Galletas"]["suggested_servings"],
        by_name["Galletas"]["suggested_quantity"],
    ) == (1, 30)
    assert (by_name["Leche"]["suggested_servings"], by_name["Leche"]["suggested_quantity"]) == (
        None,
        100,
    )
    assert by_name["Leche"]["last_used_at"] is None and by_name["Leche"]["is_favorite"] is True


async def test_eventos_de_favoritos_sin_el_alimento(client, user, make_food, capsys):
    account, headers = user
    food = await make_food("Alimento secreto de prueba")
    capsys.readouterr()
    await client.put(f"/v1/foods/favorites/{food}", headers=headers)
    await client.delete(f"/v1/foods/favorites/{food}", headers=headers)
    out = capsys.readouterr().out
    events = [json.loads(line) for line in out.splitlines() if line.startswith("{")]
    fav = [e for e in events if str(e.get("event", "")).startswith("favorite_")]
    assert {e["event"] for e in fav} == {"favorite_added", "favorite_removed"}
    for e in fav:
        assert set(e) >= {"user_id", "duration_ms"}
        assert "food_name" not in e and "food_id" not in e
    assert "secreto" not in out and str(food) not in "".join(json.dumps(e) for e in fav)
