"""SC-001: al menos 45 de los 50 casos de search-cases.md salen entre los 5 primeros."""

from pathlib import Path

import pytest

from mykcal.foods.load_generic import DEFAULT_SEED, import_generic
from mykcal.foods.text import normalize

CASES_PATH = (
    Path(__file__).resolve().parents[3] / "specs/003-base-de-alimentos/contracts/search-cases.md"
)
MIN_PASSING = 45

pytestmark = pytest.mark.skipif(
    not DEFAULT_SEED.exists(),
    reason="Falta la semilla real generic_foods.csv (T027: requiere los ficheros de CIQUAL)",
)


def load_cases() -> list[tuple[str, list[str]]]:
    cases = []
    for line in CASES_PATH.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| ") or not line[2].isdigit():
            continue
        number, query, accepted = line.strip().strip("|").strip().split(" | ", 2)
        cases.append((query.strip(), [normalize(a) for a in accepted.strip().split("|")]))
    return cases


@pytest.fixture
async def ready(app, user_with_consent):
    await import_generic(app.state.sessionmaker, DEFAULT_SEED)
    _, headers = await user_with_consent("buscador")
    return headers


def test_la_tabla_tiene_50_casos():
    assert len(load_cases()) == 50


async def test_sc001_45_de_50_entre_los_5_primeros(client, ready):
    failures = []
    for query, prefixes in load_cases():
        resp = await client.get("/v1/foods/search", params={"q": query}, headers=ready)
        assert resp.status_code == 200, query
        top5 = [normalize(item["name"]) for item in resp.json()["items"][:5]]
        if not any(name.startswith(p) for name in top5 for p in prefixes):
            failures.append(query)
    passing = len(load_cases()) - len(failures)
    print(f"SC-001: {passing}/50 (fallan: {failures})")
    assert passing >= MIN_PASSING, f"fallan: {failures}"


async def test_platano_con_tilde_en_el_nombre_y_sin_tilde_en_la_consulta(client, ready):
    resp = await client.get("/v1/foods/search", params={"q": "platano"}, headers=ready)
    assert resp.json()["items"][0]["name"].startswith("Plátano")


async def test_mayusculas_y_tildes_dan_lo_mismo(client, ready):
    results = []
    for q in ("platano", "PLÁTANO", "Platano"):
        resp = await client.get("/v1/foods/search", params={"q": q}, headers=ready)
        results.append([i["id"] for i in resp.json()["items"]])
    assert results[0] == results[1] == results[2]


async def test_consulta_corta_es_400(client, ready):
    resp = await client.get("/v1/foods/search", params={"q": "p"}, headers=ready)
    assert resp.status_code == 400
    assert resp.json()["code"] == "VALIDATION_ERROR"
    assert resp.json()["fields"] == ["q"]


async def test_sin_coincidencias(client, ready):
    resp = await client.get("/v1/foods/search", params={"q": "xyzzy"}, headers=ready)
    assert resp.status_code == 200
    assert resp.json() == {"items": []}
