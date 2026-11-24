"""R9: orden de búsqueda por código de barras con Open Food Facts simulado (FR-018)."""

import json
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import pytest

from mykcal import clock

FIXTURES = Path(__file__).parent.parent / "fixtures" / "off"
GRAMS, ML, KJ, NO_MACROS, NOT_FOUND = (
    "8410000000016",
    "8410000000023",
    "8410000000030",
    "8410000000047",
    "8410000000054",
)
BY_CODE = {
    GRAMS: "found_grams",
    ML: "found_ml",
    KJ: "kj_only",
    NO_MACROS: "no_macros",
    NOT_FOUND: "not_found",
}


class FakeOff:
    """Transporte de OFF que cuenta las peticiones y puede fallar."""

    def __init__(self) -> None:
        self.requests: list[httpx.Request] = []
        self.fail: str | None = None

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if self.fail == "timeout":
            raise httpx.ReadTimeout("lento", request=request)
        if self.fail == "network":
            raise httpx.ConnectError("sin red", request=request)
        if self.fail == "5xx":
            return httpx.Response(503)
        code = request.url.path.rsplit("/", 1)[-1]
        name = BY_CODE.get(code)
        if name is None:
            return httpx.Response(404, json={"status": 0})
        return httpx.Response(200, json=json.loads((FIXTURES / f"{name}.json").read_text("utf-8")))


@pytest.fixture
def off(app):
    fake = FakeOff()
    previous = app.state.off_transport
    app.state.off_transport = httpx.MockTransport(fake)
    yield fake
    app.state.off_transport = previous


async def lookup(client, headers, code):
    return await client.get("/v1/foods/barcode", params={"code": code}, headers=headers)


async def test_off_found_crea_la_copia_y_la_segunda_consulta_no_llama(
    client, user_with_consent, off
):
    _, headers = await user_with_consent("a")
    _, headers_b = await user_with_consent("b")
    first = await lookup(client, headers, GRAMS)
    assert first.status_code == 200
    body = first.json()
    assert body["result"] == "found"
    assert body["code"] == GRAMS
    assert "stale" not in body
    assert body["food"]["name"] == "Yogur natural sin azúcar"
    assert body["food"]["serving_size"] == 125
    assert body["food"]["per_100"]["sodium_mg"] == 46
    assert body["food"]["source"] == "off"
    assert len(off.requests) == 1
    # Otro usuario: se sirve de la copia compartida (US2.2, SC-002).
    second = await lookup(client, headers_b, GRAMS)
    assert second.json()["food"]["id"] == body["food"]["id"]
    assert len(off.requests) == 1


async def test_bebida_en_ml(client, user_with_consent, off):
    _, headers = await user_with_consent("a")
    body = (await lookup(client, headers, ML)).json()
    assert body["food"]["base_unit"] == "ml"
    assert body["food"]["serving_size"] == 200


async def test_copia_caducada_se_renueva(client, user_with_consent, make_food, off):
    _, headers = await user_with_consent("a")
    old = datetime.now(UTC) - timedelta(days=31)
    await make_food("Nombre antiguo", kind="packaged", barcode=GRAMS, fetched_at=old)
    body = (await lookup(client, headers, GRAMS)).json()
    assert len(off.requests) == 1
    assert body["food"]["name"] == "Yogur natural sin azúcar"
    assert "stale" not in body


async def test_copia_de_30_dias_exactos_sigue_vigente(
    client, user_with_consent, make_food, off, monkeypatch
):
    _, headers = await user_with_consent("a")
    now = datetime.now(UTC)
    monkeypatch.setattr(clock, "utcnow", lambda: now)
    await make_food("Copia", kind="packaged", barcode=GRAMS, fetched_at=now - timedelta(days=30))
    body = (await lookup(client, headers, GRAMS)).json()
    assert body["food"]["name"] == "Copia"
    assert off.requests == []


@pytest.mark.parametrize("failure", ["timeout", "network", "5xx"])
async def test_copia_caducada_con_off_caido_sale_con_stale(
    client, user_with_consent, make_food, off, failure
):
    _, headers = await user_with_consent("a")
    old = datetime.now(UTC) - timedelta(days=40)
    await make_food("Copia vieja", kind="packaged", barcode=GRAMS, fetched_at=old)
    off.fail = failure
    body = (await lookup(client, headers, GRAMS)).json()
    assert body["result"] == "found"
    assert body["stale"] is True
    assert body["food"]["name"] == "Copia vieja"


async def test_copia_caducada_y_off_ya_no_lo_tiene_sale_con_stale(
    client, user_with_consent, make_food, off
):
    _, headers = await user_with_consent("a")
    old = datetime.now(UTC) - timedelta(days=40)
    await make_food("Copia vieja", kind="packaged", barcode=NOT_FOUND, fetched_at=old)
    body = (await lookup(client, headers, NOT_FOUND)).json()
    assert body["result"] == "found"
    assert body["stale"] is True


@pytest.mark.parametrize("failure", ["timeout", "network", "5xx"])
async def test_sin_copia_y_off_caido_es_503(client, user_with_consent, off, failure):
    _, headers = await user_with_consent("a")
    off.fail = failure
    resp = await lookup(client, headers, GRAMS)
    assert resp.status_code == 503
    assert resp.json()["code"] == "FOOD_SOURCE_UNAVAILABLE"


async def test_not_found_devuelve_el_codigo_y_no_guarda(client, user_with_consent, off):
    _, headers = await user_with_consent("a")
    body = (await lookup(client, headers, NOT_FOUND)).json()
    assert body == {"result": "not_found", "code": NOT_FOUND}
    await lookup(client, headers, NOT_FOUND)
    assert len(off.requests) == 2  # no se guardó nada: se vuelve a preguntar


async def test_incomplete_devuelve_nombre_y_marca_y_no_guarda(client, user_with_consent, off):
    _, headers = await user_with_consent("a")
    body = (await lookup(client, headers, NO_MACROS)).json()
    assert body["result"] == "incomplete"
    assert body["code"] == NO_MACROS
    assert body["product_name"] == "Producto sin tabla"
    assert body["brand"] == "Marca Cuatro"
    assert "food" not in body
    await lookup(client, headers, NO_MACROS)
    assert len(off.requests) == 2


async def test_kj_se_convierte(client, user_with_consent, off):
    _, headers = await user_with_consent("a")
    body = (await lookup(client, headers, KJ)).json()
    assert body["food"]["per_100"]["kcal"] == 439.77


async def test_upc_a_se_normaliza_a_ean13(client, user_with_consent, make_food, off):
    _, headers = await user_with_consent("a")
    upc_a = "036000291452"
    await make_food("Producto UPC", kind="packaged", barcode="0" + upc_a)
    body = (await lookup(client, headers, upc_a)).json()
    assert body["code"] == "0" + upc_a
    assert body["food"]["name"] == "Producto UPC"
    assert off.requests == []


async def test_digito_de_control_mal_es_400(client, user_with_consent, off):
    _, headers = await user_with_consent("a")
    resp = await lookup(client, headers, "8410000000017")
    assert resp.status_code == 400
    assert resp.json()["code"] == "VALIDATION_ERROR"
    assert resp.json()["fields"] == ["code"]
    assert off.requests == []
    assert (await lookup(client, headers, "abc")).status_code == 400


async def test_personalizado_propio_gana_a_la_copia_y_a_off(
    client, user_with_consent, make_food, off
):
    me, headers = await user_with_consent("a")
    await make_food("Copia de OFF", kind="packaged", barcode=GRAMS)
    await make_food("Mi yogur", kind="custom", owner=me, barcode=GRAMS)
    body = (await lookup(client, headers, GRAMS)).json()
    assert body["food"]["name"] == "Mi yogur"
    assert body["food"]["is_mine"] is True
    assert off.requests == []


async def test_personalizado_de_otro_no_se_devuelve(client, user_with_consent, make_food, off):
    owner, _ = await user_with_consent("a")
    _, headers_b = await user_with_consent("b")
    await make_food("Yogur de A", kind="custom", owner=owner, barcode=GRAMS)
    body = (await lookup(client, headers_b, GRAMS)).json()
    assert body["food"]["name"] == "Yogur natural sin azúcar"
    assert len(off.requests) == 1


async def test_el_registro_no_lleva_el_codigo(client, user_with_consent, off, caplog):
    import logging

    from mykcal.logging import configure_logging

    configure_logging()  # deja `httpx` en WARNING, como en producción
    _, headers = await user_with_consent("a")
    with caplog.at_level(logging.INFO):
        await lookup(client, headers, GRAMS)
    assert GRAMS not in caplog.text
