"""T030 (FR-012, US3-3)."""

import pytest

pytestmark = pytest.mark.privacy


async def test_desactivada_solo_puede_leer_me(client, zitadel, make_account):
    await make_account("dis", status="disabled", name="Desactivada")
    me = await client.get("/v1/me", headers=zitadel.headers("dis"))
    assert me.status_code == 200
    assert me.json()["status"] == "disabled" and me.json()["is_admin"] is False
    for method, path in [("GET", "/v1/admin/invitation"), ("POST", "/v1/admin/invitation/rotate")]:
        resp = await client.request(method, path, headers=zitadel.headers("dis"))
        assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_DISABLED"


async def test_sin_cuenta_me_da_404(client, zitadel):
    resp = await client.get("/v1/me", headers=zitadel.headers("nadie"))
    assert resp.status_code == 404 and resp.json()["code"] == "ACCOUNT_NOT_REGISTERED"
    resp = await client.get("/v1/admin/invitation", headers=zitadel.headers("nadie"))
    assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_NOT_REGISTERED"


async def test_admin_desactivado_no_opera(client, zitadel, make_account):
    await make_account("admin-sub", status="disabled")
    resp = await client.get("/v1/admin/invitation", headers=zitadel.headers("admin-sub"))
    assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_DISABLED"


async def test_rutas_de_002_rechazan_cuenta_desactivada(
    client, zitadel, make_account, profile_body
):
    """SC-005: todas las rutas nuevas rechazan una cuenta dada de baja."""
    await make_account("dis", status="disabled")
    h = zitadel.headers("dis")
    calls = [
        ("POST", "/v1/consent", {"text_version": "2026-11-1"}),
        ("POST", "/v1/me/deactivation", None),
        ("GET", "/v1/profile", None),
        ("PUT", "/v1/profile", profile_body()),
        ("GET", "/v1/target", None),
        ("POST", "/v1/target/recalculate", None),
        ("GET", "/v1/weight", None),
        ("POST", "/v1/weight", {"measured_on": "2026-01-01", "weight_kg": 80}),
        ("GET", "/v1/recalc-proposal", None),
        ("POST", "/v1/recalc-proposal/accept", None),
    ]
    for method, path, body in calls:
        resp = await client.request(method, path, headers=h, json=body)
        assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_DISABLED", path
