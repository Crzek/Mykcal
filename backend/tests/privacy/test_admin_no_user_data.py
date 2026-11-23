"""T061 (FR-006, principio V): el administrador no ve datos de otros usuarios."""

import json

import pytest

pytestmark = [pytest.mark.privacy, pytest.mark.isolation]


async def test_rutas_admin_solo_devuelven_contadores_y_codigo(
    client, zitadel, seed_code, make_account
):
    await seed_code()
    await make_account("sub-de-ana", name="Ana Secreta")
    await make_account("sub-de-luis", name="Luis Secreto")
    for method, path in [("GET", "/v1/admin/invitation"), ("POST", "/v1/admin/invitation/rotate")]:
        resp = await client.request(method, path, headers=zitadel.headers("admin-sub"))
        assert resp.status_code == 200
        assert set(resp.json()) == {
            "code",
            "created_at",
            "active_accounts",
            "max_accounts",
            "free_seats",
        }
        text = json.dumps(resp.json())
        for secret in ("Ana", "Luis", "sub-de-ana", "sub-de-luis"):
            assert secret not in text


async def test_me_solo_devuelve_la_cuenta_propia(client, zitadel, make_account):
    await make_account("admin-sub", name="Erick")
    await make_account("otro", name="Otro Usuario")
    body = (await client.get("/v1/me", headers=zitadel.headers("admin-sub"))).json()
    assert body["display_name"] == "Erick"
    assert "Otro" not in json.dumps(body)
