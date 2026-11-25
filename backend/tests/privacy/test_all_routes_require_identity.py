"""T029/T035 (SC-003): toda ruta, salvo la lista pública cerrada, exige identidad válida."""

import pytest

from mykcal.main import PUBLIC_ROUTES

pytestmark = pytest.mark.privacy

# Sin cuenta activa: /v1/me (lee una desactivada) y el registro (aún no hay cuenta).
ALLOW_WITHOUT_ACTIVE_ACCOUNT = {("GET", "/v1/me"), ("POST", "/v1/registration")}


def all_operations(app) -> list[tuple[str, str]]:
    paths = app.openapi()["paths"]
    return [(m.upper(), p) for p, ops in paths.items() for m in ops]


def test_lista_publica_cerrada(app):
    ops = set(all_operations(app))
    assert PUBLIC_ROUTES == {("GET", "/v1/health"), ("GET", "/descargar/mykcal.apk")}
    assert PUBLIC_ROUTES <= ops
    assert ops - PUBLIC_ROUTES == {
        ("GET", "/v1/me"),
        ("POST", "/v1/registration"),
        ("GET", "/v1/admin/invitation"),
        ("POST", "/v1/admin/invitation/rotate"),
        ("POST", "/v1/consent"),
        ("POST", "/v1/me/deactivation"),
        ("GET", "/v1/profile"),
        ("PUT", "/v1/profile"),
        ("GET", "/v1/target"),
        ("PUT", "/v1/target"),
        ("POST", "/v1/target/recalculate"),
        ("GET", "/v1/foods/search"),
        ("GET", "/v1/foods/barcode"),
        ("GET", "/v1/foods/custom"),
        ("POST", "/v1/foods/custom"),
        ("PUT", "/v1/foods/custom/{food_id}"),
        ("DELETE", "/v1/foods/custom/{food_id}"),
        ("GET", "/v1/foods/recent"),
        ("GET", "/v1/foods/favorites"),
        ("PUT", "/v1/foods/favorites/{food_id}"),
        ("DELETE", "/v1/foods/favorites/{food_id}"),
        ("GET", "/v1/foods/{food_id}"),
        ("GET", "/v1/diary/copy-sources"),
        ("POST", "/v1/diary/copies"),
        ("DELETE", "/v1/diary/copies/{copy_id}"),
        ("GET", "/v1/diary/days/{date}"),
        ("POST", "/v1/diary/entries"),
        ("GET", "/v1/ai-key"),
        ("PUT", "/v1/ai-key"),
        ("DELETE", "/v1/ai-key"),
        ("POST", "/v1/photo-analysis"),
        ("PATCH", "/v1/diary/entries/{entry_id}"),
        ("DELETE", "/v1/diary/entries/{entry_id}"),
        ("POST", "/v1/diary/entries/{entry_id}/restore"),
    }, "hay rutas nuevas: decide si son públicas o exigen cuenta activa"


BAD_TOKENS = {
    "sin_token": None,
    "caducado": {"exp_in": -3600},
    "firma_ajena": {"signing_key": "otra"},
    "aud_ajena": {"aud": "otro"},
}


@pytest.mark.parametrize("case", list(BAD_TOKENS))
async def test_rutas_protegidas_rechazan_con_401(app, client, zitadel, case):
    kw = BAD_TOKENS[case]
    headers = {} if kw is None else zitadel.headers("u1", **kw)
    for method, path in set(all_operations(app)) - PUBLIC_ROUTES:
        body = {"invitation_code": "X"} if path == "/v1/registration" else None
        resp = await client.request(method, path, headers=headers, json=body)
        assert resp.status_code == 401, (method, path, case)
        assert resp.json()["code"] == "UNAUTHORIZED"


async def test_otras_rutas_exigen_cuenta_activa(app, client, zitadel, make_account):
    """Cualquier ruta fuera de la lista de excepciones rechaza cuenta ausente o desactivada."""
    await make_account("dis", status="disabled")
    for method, path in set(all_operations(app)) - PUBLIC_ROUTES - ALLOW_WITHOUT_ACTIVE_ACCOUNT:
        resp = await client.request(method, path, headers=zitadel.headers("sin-cuenta"))
        assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_NOT_REGISTERED"
        resp = await client.request(method, path, headers=zitadel.headers("dis"))
        assert resp.status_code == 403 and resp.json()["code"] == "ACCOUNT_DISABLED"
