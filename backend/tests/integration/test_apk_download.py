"""T067 (US5, FR-018)."""

from pathlib import Path

URL = "/descargar/mykcal.apk"


async def test_sin_apk_da_404(app, client):
    apk = Path(app.state.settings.apk_dir) / "mykcal.apk"
    apk.unlink(missing_ok=True)
    assert (await client.get(URL)).status_code == 404


async def test_con_apk_sirve_el_fichero_sin_token(app, client):
    apk = Path(app.state.settings.apk_dir) / "mykcal.apk"
    apk.write_bytes(b"PK\x03\x04apk-de-prueba")
    resp = await client.get(URL)
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/vnd.android.package-archive"
    assert resp.headers["content-disposition"] == 'attachment; filename="mykcal.apk"'
    assert resp.headers["cache-control"] == "no-cache"
    assert resp.content == b"PK\x03\x04apk-de-prueba"
    apk.unlink()
