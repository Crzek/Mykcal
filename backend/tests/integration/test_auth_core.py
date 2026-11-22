"""T022: validación del JWT contra el JWKS."""

import pytest

from tests.conftest import _key

URL = "/v1/me"


async def status(client, headers):
    return (await client.get(URL, headers=headers)).status_code


async def test_token_valido_pasa_la_validacion(client, zitadel):
    # Sin cuenta: llega a la ruta y responde 404, no 401.
    assert await status(client, zitadel.headers("u1")) == 404


@pytest.mark.parametrize(
    "kw",
    [
        {"exp_in": -120},
        {"nbf_in": 600},
        {"signing_key": "otra"},
        {"iss": "https://otro.test"},
        {"aud": "otro-proyecto"},
    ],
)
async def test_tokens_rechazados(client, zitadel, kw):
    assert await status(client, zitadel.headers("u1", **kw)) == 401


async def test_expirado_dentro_del_margen_de_30s_pasa(client, zitadel):
    assert await status(client, zitadel.headers("u1", exp_in=-10)) == 404


@pytest.mark.parametrize(
    "header",
    [
        {},
        {"Authorization": "Token abc"},
        {"Authorization": "Bearer "},
        {"Authorization": "Bearer basura"},
    ],
)
async def test_sin_bearer_o_malformado(client, header):
    resp = await client.get(URL, headers=header)
    assert resp.status_code == 401
    assert resp.headers["www-authenticate"].startswith("Bearer")
    assert resp.json()["code"] == "UNAUTHORIZED"


async def test_kid_desconocido_recarga_una_vez_y_no_mas_de_cada_5_min(client, zitadel):
    assert await status(client, zitadel.headers("u1")) == 404
    assert zitadel.jwks_calls == 1
    _key("k2")  # existe pero no está publicado
    for _ in range(3):
        assert await status(client, zitadel.headers("u1", kid="k2")) == 401
    assert zitadel.jwks_calls == 1  # sin recargas repetidas dentro de 5 min


async def test_kid_nuevo_publicado_se_recoge(app, client, zitadel):
    assert await status(client, zitadel.headers("u1")) == 404
    zitadel.published["k3"] = _key("k3")
    app.state.oidc._last_fetch -= 400  # han pasado más de 5 min
    assert await status(client, zitadel.headers("u1", kid="k3")) == 404
    assert zitadel.jwks_calls == 2


async def test_jwks_no_disponible_da_503(client, zitadel):
    zitadel.jwks_down = True
    resp = await client.get(URL, headers=zitadel.headers("u1"))
    assert resp.status_code == 503
    assert resp.json()["code"] == "AUTH_UNAVAILABLE"


async def test_jwks_caido_con_claves_en_memoria_sigue_validando(client, zitadel):
    assert await status(client, zitadel.headers("u1")) == 404
    zitadel.jwks_down = True
    assert await status(client, zitadel.headers("u1")) == 404
