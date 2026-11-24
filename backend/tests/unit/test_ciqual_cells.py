"""Lectura de la tabla CIQUAL (research R2, R3)."""

from decimal import Decimal
from pathlib import Path
from xml.sax.saxutils import escape

import pytest

from mykcal.foods.ciqual import (
    CONSTITUENTS,
    CiqualError,
    build_seed_rows,
    parse_cell,
    read_ciqual,
)


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("12,5", Decimal("12.5")),
        (" 12,5 ", Decimal("12.5")),
        ("0", Decimal("0")),
        ("1050", Decimal("1050")),
        ("-", None),
        ("", None),
        ("  ", None),
        (None, None),
        ("traces", Decimal("0")),
        ("Traces", Decimal("0")),
        ("< 0,5", Decimal("0")),
        ("<0,5", Decimal("0")),
        ("< 10", Decimal("0")),
    ],
)
def test_parse_cell(raw, expected):
    assert parse_cell(raw) == expected


@pytest.mark.parametrize("raw", ["abc", "1,2,3", "12 g", "NaN", "inf"])
def test_parse_cell_texto_no_reconocido(raw):
    with pytest.raises(CiqualError):
        parse_cell(raw)


def _xml(tag: str, rows: list[dict]) -> str:
    body = "".join(
        f"<{tag}>" + "".join(f"<{k}> {escape(str(v))} </{k}>" for k, v in row.items()) + f"</{tag}>"
        for row in rows
    )
    return f'<?xml version="1.0" encoding="utf-8"?>\n<TABLE>{body}</TABLE>'


def write_ciqual(folder: Path, *, platano: dict[str, str]) -> None:
    names = {
        "kcal": "Energie, Règlement UE N° 1169/2011 (kcal/100 g)",
        "protein_g": "Protéines, N x facteur de Jones (g/100 g)",
        "carbs_g": "Glucides (g/100 g)",
        "fat_g": "Lipides (g/100 g)",
        "fiber_g": "Fibres alimentaires (g/100 g)",
        "sodium_mg": "Sodium (mg/100 g)",
        "potassium_mg": "Potassium (mg/100 g)",
        "calcium_mg": "Calcium (mg/100 g)",
        "iron_mg": "Fer (mg/100 g)",
        "magnesium_mg": "Magnésium (mg/100 g)",
        "vitamin_d_ug": "Vitamine D (µg/100 g)",
        "vitamin_c_mg": "Vitamine C (mg/100 g)",
    }
    codes = {name: 100 + i for i, name in enumerate(names)}
    (folder / "const_2025.xml").write_text(
        _xml(
            "CONST",
            [{"const_code": codes[k], "const_nom_fr": v} for k, v in names.items()]
            + [{"const_code": 999, "const_nom_fr": "Eau (g/100 g)"}],
        ),
        encoding="utf-8",
    )
    (folder / "alim_2025.xml").write_text(
        _xml(
            "ALIM",
            [
                {"alim_code": 13016, "alim_nom_fr": "Banane, pulpe, crue"},
                {"alim_code": 20001, "alim_nom_fr": "Aliment sans macros"},
            ],
        ),
        encoding="utf-8",
    )
    compo = [{"alim_code": 13016, "const_code": codes[k], "teneur": platano[k]} for k in platano]
    compo.append({"alim_code": 13016, "const_code": 999, "teneur": "74,9"})
    compo.append({"alim_code": 20001, "const_code": codes["kcal"], "teneur": "50"})
    (folder / "compo_2025.xml").write_text(_xml("COMPO", compo), encoding="utf-8")


PLATANO = {
    "kcal": "90",
    "protein_g": "1,1",
    "carbs_g": "19,7",
    "fat_g": "0,3",
    "fiber_g": "2",
    "sodium_mg": "1",
    "potassium_mg": "358",
    "calcium_mg": "5",
    "iron_mg": "traces",
    "magnesium_mg": "27",
    "vitamin_d_ug": "-",
    "vitamin_c_mg": "< 8,7",
}


def test_constituyentes_cubren_los_12_nutrientes():
    assert len(CONSTITUENTS) == 12


def test_read_ciqual_y_semilla(tmp_path):
    write_ciqual(tmp_path, platano=PLATANO)
    table = read_ciqual(tmp_path)
    assert table.edition == "2025"
    rows = build_seed_rows(
        table, [{"ciqual_code": "13016", "name_es": "Plátano, crudo", "synonyms": "banana"}]
    )
    row = rows[0]
    assert row["name"] == "Plátano, crudo"
    assert row["synonyms"] == "banana"
    assert row["kcal"] == Decimal("90")
    assert row["protein_g"] == Decimal("1.1")
    assert row["iron_mg"] == Decimal("0")  # traces → 0
    assert row["vitamin_d_ug"] is None  # "-" → sin dato
    assert row["vitamin_c_mg"] == Decimal("0")  # "< x" → 0


def test_falta_un_obligatorio_nombra_el_codigo(tmp_path):
    write_ciqual(tmp_path, platano=PLATANO)
    table = read_ciqual(tmp_path)
    with pytest.raises(CiqualError, match="20001"):
        build_seed_rows(table, [{"ciqual_code": "20001", "name_es": "X", "synonyms": ""}])


def test_codigo_curado_que_no_existe(tmp_path):
    write_ciqual(tmp_path, platano=PLATANO)
    table = read_ciqual(tmp_path)
    with pytest.raises(CiqualError, match="99999"):
        build_seed_rows(table, [{"ciqual_code": "99999", "name_es": "X", "synonyms": ""}])


def test_obligatorio_con_guion_falla(tmp_path):
    write_ciqual(tmp_path, platano={**PLATANO, "fat_g": "-"})
    table = read_ciqual(tmp_path)
    with pytest.raises(CiqualError, match="13016"):
        build_seed_rows(table, [{"ciqual_code": "13016", "name_es": "X", "synonyms": ""}])


def test_falta_un_constituyente_en_const(tmp_path):
    write_ciqual(tmp_path, platano=PLATANO)
    text = (tmp_path / "const_2025.xml").read_text(encoding="utf-8")
    (tmp_path / "const_2025.xml").write_text(
        text.replace("Fer (mg/100 g)", "Otra cosa"), encoding="utf-8"
    )
    with pytest.raises(CiqualError, match="iron_mg"):
        read_ciqual(tmp_path)
