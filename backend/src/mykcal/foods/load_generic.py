"""Importación idempotente de la semilla de alimentos genéricos (research R4).

Uso: `python -m mykcal.foods.load_generic [ruta_a_la_semilla]`. Se lanza al arrancar el
contenedor, después de las migraciones. Si el hash de la semilla no cambia, no hace nada.
"""

from __future__ import annotations

import asyncio
import hashlib
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from sqlalchemy import select, text, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from mykcal import clock
from mykcal.config import get_settings
from mykcal.foods.ciqual import read_seed
from mykcal.foods.models import Food, FoodImport
from mykcal.foods.nutrients import NUTRIENTS
from mykcal.foods.text import normalize
from mykcal.logging import configure_logging, get_logger

DEFAULT_SEED = Path(__file__).parent / "data" / "generic_foods.csv"
SOURCE = "ciqual"
LOCK_KEY = 0x4D594B46  # "MYKF", distinto del de las migraciones


@dataclass
class ImportResult:
    status: Literal["done", "noop"]
    upserted: int
    archived: int


async def import_generic(
    sessionmaker: async_sessionmaker, seed_path: Path = DEFAULT_SEED
) -> ImportResult:
    log = get_logger()
    raw = seed_path.read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    seed = read_seed(seed_path)
    now = clock.utcnow()

    async with sessionmaker() as session, session.begin():
        # Dos contenedores a la vez: el segundo espera y después ve el hash ya guardado.
        await session.execute(text("SELECT pg_advisory_xact_lock(:k)"), {"k": LOCK_KEY})
        last = (
            await session.execute(
                select(FoodImport.sha256)
                .where(FoodImport.source == SOURCE)
                .order_by(FoodImport.imported_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        if last == sha:
            log.info("generic_import_noop", sha256=sha, rows=len(seed.rows))
            return ImportResult("noop", 0, 0)

        records = [
            {
                "kind": "generic",
                "name": row["name"],
                "base_unit": "g",
                "synonyms": row["synonyms"],
                "search_text": normalize(" ".join(p for p in (row["name"], row["synonyms"]) if p)),
                "source": SOURCE,
                "source_code": row["ciqual_code"],
                "archived_at": None,
                "created_at": now,
                "updated_at": now,
                **{n: row[n] for n in NUTRIENTS},
            }
            for row in seed.rows
        ]
        if records:
            stmt = insert(Food).values(records)
            update_cols = {
                c: stmt.excluded[c]
                for c in records[0]
                if c not in ("kind", "source", "source_code", "created_at")
            }
            await session.execute(
                stmt.on_conflict_do_update(
                    index_elements=[Food.source, Food.source_code],
                    index_where=text("kind = 'generic'"),
                    set_=update_cols,
                )
            )
        codes = [row["ciqual_code"] for row in seed.rows]
        archived = (
            await session.execute(
                update(Food)
                .where(
                    Food.kind == "generic",
                    Food.archived_at.is_(None),
                    Food.source_code.not_in(codes),
                )
                .values(archived_at=now, updated_at=now)
            )
        ).rowcount
        session.add(
            FoodImport(
                source=SOURCE,
                edition=seed.edition,
                sha256=sha,
                rows_upserted=len(records),
                rows_archived=archived,
                imported_at=now,
            )
        )
    log.info(
        "generic_import_done",
        sha256=sha,
        edition=seed.edition,
        rows_upserted=len(records),
        rows_archived=archived,
    )
    return ImportResult("done", len(records), archived)


async def _run(seed_path: Path) -> None:
    engine: AsyncEngine = create_async_engine(get_settings().database_url)
    try:
        await import_generic(async_sessionmaker(engine, expire_on_commit=False), seed_path)
    finally:
        await engine.dispose()


def main(argv: list[str] | None = None) -> int:
    configure_logging()
    args = sys.argv[1:] if argv is None else argv
    seed_path = Path(args[0]) if args else DEFAULT_SEED
    try:
        asyncio.run(_run(seed_path))
    except Exception as exc:  # noqa: BLE001
        get_logger().error("generic_import_failed", error_class=type(exc).__name__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
