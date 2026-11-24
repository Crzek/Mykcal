"""FR-018: la guarda de conftest impide llamar a Open Food Facts de verdad."""

import httpx
import pytest


async def test_cliente_real_de_off_falla():
    async with httpx.AsyncClient() as client:
        with pytest.raises(AssertionError, match="Open Food Facts"):
            await client.get("https://world.openfoodfacts.org/api/v2/product/1")


async def test_mock_transport_si_funciona():
    transport = httpx.MockTransport(lambda request: httpx.Response(200, json={"status": 0}))
    async with httpx.AsyncClient(transport=transport) as client:
        resp = await client.get("https://world.openfoodfacts.org/api/v2/product/1")
    assert resp.json() == {"status": 0}
