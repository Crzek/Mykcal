"""Genera la semilla de alimentos genéricos a partir de CIQUAL (research R2, R3).

Uso:
    uv run python scripts/build_generic_seed.py <carpeta_ciqual> <ciqual_es.csv> <salida.csv>

`<carpeta_ciqual>` contiene `alim_*.xml`, `const_*.xml` y `compo_*.xml` de CIQUAL, descargados a
mano y fuera de git (ver quickstart.md §0). Falla si un código curado no existe en CIQUAL o si
al alimento le falta kcal, proteína, carbohidratos o grasa.
"""

from __future__ import annotations

import sys
from pathlib import Path

from mykcal.foods.ciqual import (
    CiqualError,
    build_seed_rows,
    read_ciqual,
    read_curated,
    write_seed,
)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    folder, curated_path, out_path = (Path(a) for a in argv)
    try:
        table = read_ciqual(folder)
        rows = build_seed_rows(table, read_curated(curated_path))
    except CiqualError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    write_seed(out_path, table.edition, rows)
    print(f"CIQUAL {table.edition}: {len(rows)} alimentos escritos en {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
