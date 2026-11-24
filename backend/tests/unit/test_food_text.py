import pytest

from mykcal.foods.text import normalize


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Plátano", "platano"),
        ("PIÑA", "pina"),
        ("Jamón", "jamon"),
        ("Pingüino", "pinguino"),
        ("  Arroz   Cocido ", "arroz cocido"),
        ("ÁÉÍÓÚ", "aeiou"),
        ("", ""),
    ],
)
def test_normalize(raw, expected):
    assert normalize(raw) == expected


def test_normalize_es_idempotente():
    once = normalize("  Plátano   de CANARIAS ")
    assert normalize(once) == once
