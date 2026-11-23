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
