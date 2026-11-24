import pytest
from pydantic import ValidationError

from mykcal.config import Settings

BASE = dict(
    database_url="postgresql://u:p@db/mykcal",
    oidc_issuer="https://zitadel.test",
    oidc_project_id="p",
    admin_subject="a",
)


def make(**over):
    return Settings(_env_file=None, **{**BASE, **over})


def test_ok_y_convierte_esquema():
    assert make().database_url.startswith("postgresql+asyncpg://")


@pytest.mark.parametrize(
    "missing", ["database_url", "oidc_issuer", "oidc_project_id", "admin_subject"]
)
def test_falta_variable_obligatoria(missing, monkeypatch):
    for key in BASE:
        monkeypatch.delenv(key.upper(), raising=False)
    data = {k: v for k, v in BASE.items() if k != missing}
    with pytest.raises(ValidationError) as err:
        Settings(_env_file=None, **data)
    assert missing in str(err.value)
    assert "postgresql://u:p" not in str(err.value)


@pytest.mark.parametrize("issuer", ["http://zitadel.test", "https://zitadel.test/"])
def test_issuer_invalido(issuer):
    with pytest.raises(ValidationError):
        make(oidc_issuer=issuer)


def test_host_externo_exige_ssl():
    with pytest.raises(ValidationError):
        make(database_url="postgresql://u:p@db.example.com/mykcal")
    assert make(database_url="postgresql://u:p@db.example.com/mykcal?ssl=require")


@pytest.mark.parametrize("host", ["localhost", "10.0.0.5", "127.0.0.1", "mykcal-db"])
def test_host_interno_sin_tls(host):
    assert make(database_url=f"postgresql://u:p@{host}/mykcal")


def test_open_food_facts_por_defecto():
    s = make()
    assert s.off_base_url == "https://world.openfoodfacts.org"
    assert s.off_user_agent.startswith("Mykcal/")
    assert s.off_timeout_s == 5.0


def test_off_url_sin_https_rechazada():
    with pytest.raises(ValidationError):
        make(off_base_url="http://world.openfoodfacts.org")


@pytest.mark.parametrize("timeout", [0.5, 31])
def test_off_timeout_fuera_de_rango(timeout):
    with pytest.raises(ValidationError):
        make(off_timeout_s=timeout)
