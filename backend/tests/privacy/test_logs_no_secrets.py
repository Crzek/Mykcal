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


async def test_logs_sin_valores_de_salud(
    client, zitadel, make_account, grant_consent, profile_body, capsys
):
    """Principio X: edad, altura, peso y objetivo no aparecen en los logs."""
    await grant_consent(await make_account("u-salud"))
    h = zitadel.headers("u-salud")
    capsys.readouterr()
    body = profile_body(age=47, height_cm=193, weight_kg=87.3, goal="lose_fat")
    resp = await client.put("/v1/profile", json=body, headers=h)
    values = resp.json()["target"]["values"]
    await client.put("/v1/target", json=values | {"kcal": 1999}, headers=h)
    await client.put("/v1/profile", json=profile_body(age=7), headers=h)  # inválido
    out = "\n".join(_lines(capsys))
    events = [json.loads(line) for line in out.splitlines()]
    names = {e.get("event") for e in events}
    assert {"profile_saved", "target_saved"} <= names
    for e in events:
        for key in ("age", "height_cm", "weight_kg", "kcal", "sex", "goal", "weight", "values"):
            assert key not in e, (key, e)
    for needle in ("87.3", "193", "1999", "lose_fat", '"age"', "weight_kg"):
        assert needle not in out, needle
    assert any(e.get("source") == "manual" for e in events if e.get("event") == "target_saved")
