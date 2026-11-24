"""Importación idempotente de la semilla genérica (FR-002, research R4)."""

import asyncio
import hashlib
from decimal import Decimal

from sqlalchemy import func, select, text

from mykcal.foods.ciqual import write_seed
from mykcal.foods.load_generic import import_generic
from mykcal.foods.models import Food, FoodImport
from mykcal.foods.nutrients import NUTRIENTS


def seed_row(code: str, name: str, *, synonyms: str = "", **over) -> dict:
    row = {"ciqual_code": code, "name": name, "synonyms": synonyms}
    row.update({n: None for n in NUTRIENTS})
    row.update(kcal=Decimal("90"), protein_g=Decimal("1.1"), carbs_g=Decimal("19.7"))
    row.update(fat_g=Decimal("0.3"))
    row.update({k: (Decimal(str(v)) if v is not None else None) for k, v in over.items()})
    return row


async def count(app, *where) -> int:
    async with app.state.sessionmaker() as s:
        return (await s.execute(select(func.count()).select_from(Food).where(*where))).scalar_one()


async def test_dos_cargas_no_duplican_y_la_segunda_es_noop(app, tmp_path, capsys):
    seed = tmp_path / "seed.csv"
    write_seed(seed, "2025", [seed_row("1", "Plátano, crudo"), seed_row("2", "Manzana, cruda")])

    capsys.readouterr()
    first = await import_generic(app.state.sessionmaker, seed)
    assert (first.status, first.upserted, first.archived) == ("done", 2, 0)
    done = capsys.readouterr().out
    assert "generic_import_done" in done
    assert '"rows_upserted": 2' in done
    assert await count(app, Food.kind == "generic") == 2

    capsys.readouterr()
    second = await import_generic(app.state.sessionmaker, seed)
    assert second.status == "noop"
    assert await count(app, Food.kind == "generic") == 2
    out = capsys.readouterr().out
    assert "generic_import_noop" in out
    assert "Plátano" not in out  # los registros no llevan contenido de alimentos


async def test_registra_la_importacion(app, tmp_path):
    seed = tmp_path / "seed.csv"
    write_seed(seed, "2025", [seed_row("1", "Plátano, crudo")])
    await import_generic(app.state.sessionmaker, seed)
    async with app.state.sessionmaker() as s:
        imports = (await s.execute(select(FoodImport))).scalars().all()
    assert len(imports) == 1
    assert imports[0].source == "ciqual"
    assert imports[0].edition == "2025"
    assert imports[0].sha256 == hashlib.sha256(seed.read_bytes()).hexdigest()
    assert (imports[0].rows_upserted, imports[0].rows_archived) == (1, 0)


async def test_cambiar_un_valor_actualiza_sin_duplicar(app, tmp_path):
    seed = tmp_path / "seed.csv"
    write_seed(seed, "2025", [seed_row("1", "Plátano, crudo")])
    await import_generic(app.state.sessionmaker, seed)
    write_seed(seed, "2025", [seed_row("1", "Plátano, crudo", kcal=95)])
    result = await import_generic(app.state.sessionmaker, seed)
    assert result.status == "done"
    async with app.state.sessionmaker() as s:
        foods = (await s.execute(select(Food))).scalars().all()
    assert len(foods) == 1
    assert foods[0].kcal == Decimal("95.00")


async def test_quitar_archiva_y_volver_desarchiva(app, tmp_path):
    seed = tmp_path / "seed.csv"
    both = [seed_row("1", "Plátano, crudo"), seed_row("2", "Manzana, cruda")]
    write_seed(seed, "2025", both)
    await import_generic(app.state.sessionmaker, seed)

    write_seed(seed, "2025", both[:1])
    result = await import_generic(app.state.sessionmaker, seed)
    assert result.archived == 1
    assert await count(app, Food.kind == "generic", Food.archived_at.is_not(None)) == 1
    async with app.state.sessionmaker() as s:
        archived = (
            await s.execute(select(Food.source_code).where(Food.archived_at.is_not(None)))
        ).scalar_one()
    assert archived == "2"

    write_seed(seed, "2025", both)
    await import_generic(app.state.sessionmaker, seed)
    assert await count(app, Food.archived_at.is_not(None)) == 0
    assert await count(app, Food.kind == "generic") == 2


async def test_sin_dato_sigue_siendo_null_y_el_cero_es_cero(app, tmp_path):
    seed = tmp_path / "seed.csv"
    write_seed(seed, "2025", [seed_row("1", "Agua", fiber_g=0, vitamin_d_ug=None, kcal=0)])
    await import_generic(app.state.sessionmaker, seed)
    async with app.state.sessionmaker() as s:
        food = (await s.execute(select(Food))).scalar_one()
    assert food.fiber_g == Decimal("0.00")
    assert food.vitamin_d_ug is None
    assert food.sodium_mg is None


async def test_sinonimos_y_texto_de_busqueda(app, tmp_path):
    seed = tmp_path / "seed.csv"
    write_seed(
        seed, "2025", [seed_row("1", "Plátano, crudo", synonyms="banana|plátano de Canarias")]
    )
    await import_generic(app.state.sessionmaker, seed)
    async with app.state.sessionmaker() as s:
        food = (await s.execute(select(Food))).scalar_one()
    assert food.kind == "generic"
    assert food.source == "ciqual"
    assert food.base_unit == "g"
    assert food.synonyms == "banana|plátano de Canarias"
    assert "platano" in food.search_text
    assert "banana" in food.search_text
    assert "canarias" in food.search_text
    assert "á" not in food.search_text


async def test_dos_cargas_concurrentes_no_duplican(app, tmp_path):
    seed = tmp_path / "seed.csv"
    write_seed(seed, "2025", [seed_row(str(i), f"Alimento {i}") for i in range(30)])
    results = await asyncio.gather(
        import_generic(app.state.sessionmaker, seed),
        import_generic(app.state.sessionmaker, seed),
    )
    assert sorted(r.status for r in results) == ["done", "noop"]
    assert await count(app, Food.kind == "generic") == 30
    async with app.state.sessionmaker() as s:
        n = (await s.execute(text("SELECT count(*) FROM food_import"))).scalar_one()
    assert n == 1
