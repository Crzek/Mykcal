"""Orden y límites de la búsqueda (research R6, FR-004, FR-005)."""

from datetime import UTC, datetime


async def names(client, headers, q: str) -> list[str]:
    resp = await client.get("/v1/foods/search", params={"q": q}, headers=headers)
    assert resp.status_code == 200, resp.text
    return [i["name"] for i in resp.json()["items"]]


async def test_orden_de_tipos_propios_genericos_envasados(client, user_with_consent, make_food):
    me, headers = await user_with_consent("u1")
    await make_food("Arroz Brillante", kind="packaged", barcode="8410000000009", brand="Marca")
    await make_food("Arroz cocido", kind="generic")
    await make_food("Arroz casero", kind="custom", owner=me)
    assert await names(client, headers, "arroz") == [
        "Arroz casero",
        "Arroz cocido",
        "Arroz Brillante",
    ]


async def test_orden_dentro_de_un_tipo(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    for name in ("Carrozas", "Sopa de arroz", "Arroz cocido", "Arroz"):
        await make_food(name)
    assert await names(client, headers, "arroz") == [
        "Arroz",  # nombre exacto
        "Arroz cocido",  # empieza por la consulta
        "Sopa de arroz",  # una palabra empieza por la consulta
        "Carrozas",  # el resto
    ]


async def test_empate_gana_el_nombre_mas_corto(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    await make_food("Plátano macho, frito")
    await make_food("Plátano, crudo")
    assert await names(client, headers, "platano") == ["Plátano, crudo", "Plátano macho, frito"]


async def test_sinonimos_y_marca_cuentan(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    await make_food("Plátano, crudo", synonyms="banana|plátano de Canarias")
    await make_food("Galletas", kind="packaged", barcode="8410000000009", brand="Bananera")
    found = await names(client, headers, "banana")
    assert found[0] == "Plátano, crudo"
    assert "Galletas" in found


async def test_consulta_de_varias_palabras(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    await make_food("Arroz, cocido")
    await make_food("Arroz integral, cocido")
    await make_food("Pasta, cocida")
    found = await names(client, headers, "arroz cocido")
    assert "Pasta, cocida" not in found
    assert "Arroz, cocido" in found


async def test_tolera_una_errata_leve(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    await make_food("Arroz, cocido")
    assert "Arroz, cocido" in await names(client, headers, "arros")


async def test_maximo_20(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    for i in range(25):
        await make_food(f"Pera variedad {i:02d}")
    assert len(await names(client, headers, "pera")) == 20


async def test_no_salen_archivados_ni_eliminados_ni_ajenos(client, user_with_consent, make_food):
    me, headers = await user_with_consent("u1")
    other, _ = await user_with_consent("u2")
    now = datetime.now(UTC)
    await make_food("Lentejas visibles")
    await make_food("Lentejas archivadas", archived_at=now)
    await make_food("Lentejas eliminadas", kind="custom", owner=me, deleted_at=now)
    await make_food("Lentejas de otra persona", kind="custom", owner=other)
    await make_food("Lentejas mías", kind="custom", owner=me)
    assert sorted(await names(client, headers, "lentejas")) == [
        "Lentejas mías",
        "Lentejas visibles",
    ]


async def test_is_mine_solo_en_los_propios(client, user_with_consent, make_food):
    me, headers = await user_with_consent("u1")
    await make_food("Tarta de la abuela", kind="custom", owner=me)
    await make_food("Tarta de queso")
    resp = await client.get("/v1/foods/search", params={"q": "tarta"}, headers=headers)
    items = {i["name"]: i for i in resp.json()["items"]}
    assert items["Tarta de la abuela"]["is_mine"] is True
    assert items["Tarta de la abuela"]["kind"] == "custom"
    assert items["Tarta de queso"]["is_mine"] is False
    assert items["Tarta de queso"]["kcal"] == 100.0
    assert items["Tarta de queso"]["base_unit"] == "g"


async def test_caracteres_especiales_en_la_consulta(client, user_with_consent, make_food):
    _, headers = await user_with_consent("u1")
    await make_food("Zumo 100% naranja")
    assert await names(client, headers, "100%") == ["Zumo 100% naranja"]
    assert await names(client, headers, "a_b") == []
