"""T015 (005): GET /v1/foods/recent (FR-001, research R1, R2)."""

from datetime import UTC, datetime, timedelta

import pytest

TODAY = datetime.now(UTC).date()
NOW = datetime.now(UTC)


@pytest.fixture
async def user(user_with_consent, make_target_version):
    account, headers = await user_with_consent("recent-user")
    await make_target_version(account, NOW - timedelta(days=30))
    return account, headers


async def recent(client, headers):
    resp = await client.get("/v1/foods/recent", headers=headers)
    assert resp.status_code == 200, resp.text
    return resp.json()["items"]


async def test_sin_entradas_devuelve_lista_vacia(client, user):
    _, headers = user
    assert await recent(client, headers) == []


async def test_un_alimento_registrado_tres_veces_sale_una_con_su_ultima_cantidad(
    client, user, make_entry, make_food
):
    account, headers = user
    food = await make_food("Pan de molde")
    for i, qty in enumerate((60, 90, 120)):
        await make_entry(
            account, TODAY, food_id=food, quantity=qty, created_at=NOW - timedelta(hours=3 - i)
        )
    items = await recent(client, headers)
    assert len(items) == 1
    assert items[0]["food"]["id"] == str(food)
    assert items[0]["suggested_quantity"] == 120 and items[0]["suggested_servings"] is None
    assert items[0]["is_favorite"] is False and items[0]["last_used_at"] is not None


async def test_35_alimentos_distintos_devuelven_30_por_ultimo_uso(
    client, user, make_entry, make_food
):
    account, headers = user
    for i in range(35):
        food = await make_food(f"Alimento {i:02d}")
        await make_entry(account, TODAY, food_id=food, created_at=NOW - timedelta(minutes=100 - i))
    items = await recent(client, headers)
    assert len(items) == 30
    assert items[0]["food"]["name"] == "Alimento 34"
    assert items[-1]["food"]["name"] == "Alimento 05"


async def test_una_entrada_borrada_no_cuenta(client, user, make_entry, make_food):
    account, headers = user
    solo = await make_food("Solo borrado")
    ambos = await make_food("Con una viva")
    await make_entry(account, TODAY, food_id=solo, deleted_at=NOW)
    await make_entry(
        account, TODAY, food_id=ambos, quantity=40, created_at=NOW - timedelta(hours=2)
    )
    await make_entry(account, TODAY, food_id=ambos, quantity=999, deleted_at=NOW, created_at=NOW)
    items = await recent(client, headers)
    assert [i["food"]["name"] for i in items] == ["Con una viva"]
    assert items[0]["suggested_quantity"] == 40  # la última ACTIVA


async def test_no_disponibles_no_salen_y_se_completan_los_30(client, user, make_entry, make_food):
    account, headers = user
    borrado = await make_food("Personalizado borrado", kind="custom", owner=account, deleted_at=NOW)
    archivado = await make_food("Genérico archivado", archived_at=NOW)
    await make_entry(account, TODAY, food_id=borrado, created_at=NOW)
    await make_entry(account, TODAY, food_id=archivado, created_at=NOW)
    for i in range(30):
        food = await make_food(f"Válido {i:02d}")
        await make_entry(
            account, TODAY, food_id=food, created_at=NOW - timedelta(hours=1, minutes=i)
        )
    items = await recent(client, headers)
    names = {i["food"]["name"] for i in items}
    assert len(items) == 30
    assert "Personalizado borrado" not in names and "Genérico archivado" not in names


async def test_la_lista_es_global_no_depende_de_la_comida(client, user, make_entry, make_food):
    account, headers = user
    for meal in ("breakfast", "dinner"):
        food = await make_food(f"Plato de {meal}")
        await make_entry(account, TODAY, meal, food_id=food)
    assert len(await recent(client, headers)) == 2


async def test_is_favorite_refleja_los_favoritos(
    client, user, make_entry, make_food, make_favorite
):
    account, headers = user
    fav = await make_food("Favorito")
    otro = await make_food("Otro")
    await make_entry(account, TODAY, food_id=fav, created_at=NOW)
    await make_entry(account, TODAY, food_id=otro, created_at=NOW - timedelta(hours=1))
    await make_favorite(account, fav)
    flags = {i["food"]["name"]: i["is_favorite"] for i in await recent(client, headers)}
    assert flags == {"Favorito": True, "Otro": False}


async def test_la_cantidad_sugerida_conserva_las_raciones(client, user, make_entry, make_food):
    account, headers = user
    food = await make_food("Galletas", kind="packaged", barcode="8410000000009", serving_size=30)
    await make_entry(account, TODAY, food_id=food, quantity=60, servings=2)
    item = (await recent(client, headers))[0]
    assert item["suggested_quantity"] == 60 and item["suggested_servings"] == 2
