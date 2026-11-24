"""Lectura de CIQUAL (ANSES) y de la semilla de alimentos genéricos (research R1–R4).

Funciones puras salvo las que leen o escriben ficheros. No usa `float`.
"""

from __future__ import annotations

import csv
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from decimal import Decimal
from pathlib import Path

from mykcal.foods.nutrients import NUTRIENTS, REQUIRED_NUTRIENTS
from mykcal.foods.text import normalize

SEED_NAME_LIMIT = 120
_NUMBER = re.compile(r"^\d+(\.\d+)?$")
_EDITION = re.compile(r"_(\d{4})")

# Nutriente → comienzo del nombre del constituyente en CIQUAL (comparado normalizado).
CONSTITUENTS: dict[str, str] = {
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

SEED_COLUMNS = ["ciqual_code", "name", "synonyms", *NUTRIENTS]


class CiqualError(ValueError):
    """Dato de CIQUAL o del CSV curado que no se puede usar."""


def parse_cell(raw: str | None) -> Decimal | None:
    """Convierte una celda de CIQUAL (R3). `None` = sin dato; trazas y «< x» = 0."""
    if raw is None:
        return None
    text = raw.strip()
    if text in ("", "-"):
        return None
    lowered = text.lower()
    if lowered == "traces":
        return Decimal(0)
    if lowered.startswith("<"):
        parse_cell(text[1:])  # valida que lo que sigue sea un número
        return Decimal(0)
    normalized = text.replace(",", ".")
    if not _NUMBER.match(normalized):
        raise CiqualError(f"valor no reconocido: {text!r}")
    return Decimal(normalized)


@dataclass
class CiqualTable:
    edition: str
    names: dict[str, str] = field(default_factory=dict)
    # código CIQUAL → nutriente → valor (`None` = sin dato; ausente = sin dato)
    values: dict[str, dict[str, Decimal | None]] = field(default_factory=dict)


def _rows(path: Path) -> list[dict[str, str]]:
    root = ET.parse(path).getroot()  # noqa: S314 — fichero oficial descargado a mano
    return [{child.tag: (child.text or "").strip() for child in row} for row in root]


def _only(folder: Path, prefix: str) -> Path:
    found = sorted(folder.glob(f"{prefix}_*.xml"))
    if len(found) != 1:
        raise CiqualError(f"se esperaba un único {prefix}_*.xml en {folder}, hay {len(found)}")
    return found[0]


def read_ciqual(folder: Path) -> CiqualTable:
    """Lee `alim_*.xml`, `const_*.xml` y `compo_*.xml` de la carpeta descargada de CIQUAL."""
    compo_path = _only(folder, "compo")
    match = _EDITION.search(compo_path.name)
    table = CiqualTable(edition=match.group(1) if match else "desconocida")

    wanted: dict[str, str] = {}  # const_code → nutriente
    const_names = {
        r["const_code"]: r.get("const_nom_fr", "") for r in _rows(_only(folder, "const"))
    }
    for nutrient, prefix in CONSTITUENTS.items():
        target = normalize(prefix)
        hits = [c for c, n in const_names.items() if normalize(n).startswith(target)]
        if len(hits) != 1:
            raise CiqualError(f"constituyente de {nutrient}: {len(hits)} coincidencias")
        wanted[hits[0]] = nutrient

    for row in _rows(_only(folder, "alim")):
        table.names[row["alim_code"]] = row.get("alim_nom_fr", "")
    for row in _rows(compo_path):
        nutrient = wanted.get(row["const_code"])
        if nutrient is None:
            continue
        try:
            value = parse_cell(row.get("teneur"))
        except CiqualError as exc:
            raise CiqualError(f"alimento {row['alim_code']}, {nutrient}: {exc}") from exc
        table.values.setdefault(row["alim_code"], {})[nutrient] = value
    return table


def build_seed_rows(table: CiqualTable, curated: list[dict[str, str]]) -> list[dict]:
    """Une la selección curada con los valores de CIQUAL. Falla si falta algo obligatorio."""
    rows: list[dict] = []
    seen: set[str] = set()
    for entry in curated:
        code = entry["ciqual_code"].strip()
        if code in seen:
            raise CiqualError(f"código CIQUAL repetido en el CSV curado: {code}")
        seen.add(code)
        if code not in table.values:
            raise CiqualError(f"el código CIQUAL {code} no existe en la tabla")
        name = entry["name_es"].strip()
        if not 1 <= len(name) <= SEED_NAME_LIMIT:
            raise CiqualError(f"nombre no válido para el código {code}")
        values = table.values[code]
        missing = [n for n in REQUIRED_NUTRIENTS if values.get(n) is None]
        if missing:
            raise CiqualError(f"el alimento {code} no tiene {', '.join(missing)}")
        rows.append(
            {
                "ciqual_code": code,
                "name": name,
                "synonyms": (entry.get("synonyms") or "").strip(),
                **{n: values.get(n) for n in NUTRIENTS},
            }
        )
    return rows


def read_curated(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter=";")
        return [row for row in reader if (row.get("ciqual_code") or "").strip()]


def write_seed(path: Path, edition: str, rows: list[dict]) -> None:
    """Escribe la semilla: una línea `# ciqual_edition=…` y un CSV con comas."""
    with path.open("w", encoding="utf-8", newline="") as fh:
        fh.write(f"# ciqual_edition={edition}\n")
        writer = csv.writer(fh)
        writer.writerow(SEED_COLUMNS)
        for row in rows:
            writer.writerow(
                [
                    "" if row[c] is None else format(row[c], "f") if c in NUTRIENTS else row[c]
                    for c in SEED_COLUMNS
                ]
            )


@dataclass
class SeedFile:
    edition: str
    rows: list[dict]


def read_seed(path: Path) -> SeedFile:
    """Lee la semilla. Un nutriente vacío es `None` (sin dato), nunca 0 (FR-003)."""
    with path.open(encoding="utf-8", newline="") as fh:
        first = fh.readline()
        match = re.match(r"# ciqual_edition=(.+)", first)
        if not match:
            raise CiqualError("la semilla debe empezar con «# ciqual_edition=…»")
        reader = csv.DictReader(fh)
        rows = []
        for raw in reader:
            row: dict = {
                "ciqual_code": raw["ciqual_code"],
                "name": raw["name"],
                "synonyms": raw["synonyms"] or None,
            }
            for n in NUTRIENTS:
                row[n] = Decimal(raw[n]) if raw[n] != "" else None
            rows.append(row)
    return SeedFile(edition=match.group(1).strip(), rows=rows)
