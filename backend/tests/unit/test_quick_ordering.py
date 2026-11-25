"""T034 (005): orden de favoritos (contracts/quick-cases.md O1–O4, FR-010)."""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace as NS

from mykcal.quick.ordering import order_favorites

NOW = datetime(2026, 11, 24, 12, tzinfo=UTC)


def fav(name, ago: timedelta | None):
    return NS(name=name, last_used_at=None if ago is None else NOW - ago)


def names(items):
    return [i.name for i in order_favorites(items)]


def test_o1_por_ultimo_uso_descendente():
    items = [
        fav("Yogur", timedelta(days=1, hours=3)),
        fav("Avena", timedelta(hours=4)),
        fav("Plátano", timedelta(days=3)),
    ]
    assert names(items) == ["Avena", "Yogur", "Plátano"]


def test_o2_los_nunca_usados_al_final_por_nombre():
    items = [
        fav("Zumo", None),
        fav("Ñoquis", None),
        fav("Aceite", None),
        fav("Leche", timedelta(hours=1)),
    ]
    assert names(items) == ["Leche", "Aceite", "Ñoquis", "Zumo"]


def test_o3_sin_tildes_ni_mayusculas():
    items = [fav("Álamo", None), fav("alubias", None), fav("Arroz", None)]
    assert names(items) == ["Álamo", "alubias", "Arroz"]


def test_o4_empate_de_uso_se_desempata_por_nombre():
    same = timedelta(hours=2)
    assert names([fav("Pan", same), fav("Huevo", same)]) == ["Huevo", "Pan"]
