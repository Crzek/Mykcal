"""Migraciones al arrancar: sin cambios no hace nada; con la base al día es idempotente."""

import uuid
from datetime import datetime

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from mykcal.migrate import migrate


async def test_migrar_con_la_base_al_dia_es_noop(settings, migrated, capsys):
    capsys.readouterr()
    await migrate(settings)
    out = capsys.readouterr().out
    assert "migrate_noop" in out
    assert "migrate_start" not in out


async def test_0002_tablas_y_restricciones(app, make_account):
    """T008: la migración 0002 crea las tablas y los CHECK de data-model.md."""
    acc = await make_account("mig-user")
    now = "now()"

    async def run(sql: str, **params) -> None:
        async with app.state.engine.begin() as conn:
            await conn.execute(text(sql), {"u": acc.id, **params})

    insert_profile = (
        "INSERT INTO user_profile (user_id, age, sex, height_cm, activity_level, goal, "
        f"created_at, updated_at) VALUES (:u, :age, 'male', :h, 'light', 'maintain', {now}, {now})"
    )
    await run(insert_profile, age=30, h=180)
    for age, h in ((17, 180), (101, 180), (30, 99), (30, 251)):
        async with app.state.engine.begin() as conn:
            await conn.execute(text("DELETE FROM user_profile"))
        with pytest.raises(IntegrityError):
            await run(insert_profile, age=age, h=h)

    insert_weight = (
        "INSERT INTO weight_entry (user_id, measured_on, weight_kg, created_at, updated_at) "
        f"VALUES (:u, current_date, :w, {now}, {now})"
    )
    with pytest.raises(IntegrityError):
        await run(insert_weight, w=29.9)
    await run(insert_weight, w=80.3)
    with pytest.raises(IntegrityError):  # un registro por día
        await run(insert_weight, w=81.0)

    insert_target = (
        "INSERT INTO daily_target (user_id, is_current, effective_from, superseded_at, source, "
        "kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_mg, potassium_mg, calcium_mg, iron_mg, "
        "magnesium_mg, vitamin_d_ug, vitamin_c_mg, calc_weight_kg, calc_age, calc_sex, "
        "calc_height_cm, calc_activity, calc_goal, calculated_at) "
        f"VALUES (:u, :cur, {now}, :sup, 'calculated', 2000, 100, 200, 60, 30, 2000, 3500, 1000, "
        f"8, 400, 15, 90, 80.0, 30, 'male', 180, 'light', 'maintain', {now})"
    )
    await run(insert_target, cur=True, sup=None)
    with pytest.raises(IntegrityError):  # dos vigentes del mismo usuario
        await run(insert_target, cur=True, sup=None)
    with pytest.raises(IntegrityError):  # vigente con superseded_at
        await run(insert_target, cur=True, sup=datetime.now())


async def test_0003_alimentos_restricciones(app, make_account):
    """T011: la migración 0003 crea food y food_import con los CHECK e índices de data-model.md."""
    acc = await make_account("mig-food")

    async def run(sql: str, **params) -> None:
        async with app.state.engine.begin() as conn:
            await conn.execute(text(sql), params)

    cols = "(kind, owner_user_id, name, barcode, base_unit, kcal, protein_g, carbs_g, fat_g, "
    cols += "fiber_g, search_text, source, source_code, fetched_at, deleted_at, created_at, "
    cols += "updated_at)"

    def insert(
        kind,
        *,
        owner=None,
        source="user",
        code=None,
        barcode=None,
        fetched=None,
        deleted=None,
        kcal=100,
        fiber=None,
        name="x",
    ):
        return (
            f"INSERT INTO food {cols} VALUES ('{kind}', :owner, :name, :barcode, 'g', :kcal, 1, 1, "
            "1, :fiber, 'x', :source, :code, :fetched, :deleted, now(), now())",
            dict(
                owner=owner,
                name=name,
                barcode=barcode,
                kcal=kcal,
                fiber=fiber,
                source=source,
                code=code,
                fetched=fetched,
                deleted=deleted,
            ),
        )

    now = datetime.now().astimezone()
    sql, p = insert("custom", owner=acc.id, barcode="12345678")
    await run(sql, **p)
    for bad in (
        insert("custom"),  # custom sin dueño
        insert("generic", owner=acc.id, source="ciqual", code="1"),  # genérico con dueño
        insert("generic", source="ciqual", code="2", deleted=now),  # deleted_at en un genérico
        insert("custom", owner=acc.id, barcode="1234567"),  # 7 cifras
        insert("custom", owner=acc.id, kcal=-1),
        insert("custom", owner=acc.id, kcal=901),
        insert("custom", owner=acc.id, fiber=-0.5),
        insert("custom", owner=acc.id, name=""),
        insert("generic", source="user", code="3"),  # origen incoherente con el tipo
        insert("packaged", source="off", barcode="8410000000009"),  # sin fetched_at
    ):
        with pytest.raises(IntegrityError):
            await run(bad[0], **bad[1])

    # Copia local compartida: una sola por código
    sql, p = insert("packaged", source="off", barcode="8410000000009", fetched=now)
    await run(sql, **p)
    with pytest.raises(IntegrityError):
        await run(sql, **p)

    # Mismo usuario: un personalizado activo por código; eliminado + activo sí se permite
    sql, p = insert("custom", owner=acc.id, barcode="12345678")
    with pytest.raises(IntegrityError):
        await run(sql, **p)
    await run("UPDATE food SET deleted_at = now() WHERE barcode = '12345678'")
    await run(sql, **p)

    # Genérico: único por (source, source_code); sin dato = NULL, no 0
    sql, p = insert("generic", source="ciqual", code="9000")
    await run(sql, **p)
    with pytest.raises(IntegrityError):
        await run(sql, **p)
    async with app.state.engine.connect() as conn:
        fiber = (
            await conn.execute(text("SELECT fiber_g FROM food WHERE source_code = '9000'"))
        ).scalar_one()
        ext = (
            await conn.execute(text("SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'"))
        ).scalar_one_or_none()
    assert fiber is None
    assert ext == 1


async def test_0004_diario_restricciones(app, make_account, make_food):
    """T002: la migración 0004 crea diary_entry con los CHECK e índices de data-model.md."""
    acc = await make_account("mig-diary")
    food_id = await make_food("Pan", serving_size=30)

    async def run(sql: str, **params) -> None:
        async with app.state.engine.begin() as conn:
            await conn.execute(text(sql), params)

    def insert(*, meal="breakfast", unit="g", quantity=100, servings=None, serving_size=30):
        return (
            "INSERT INTO diary_entry (user_id, entry_date, meal, food_id, food_kind, food_name, "
            "base_unit, serving_size, kcal, protein_g, carbs_g, fat_g, quantity, servings, "
            "created_at, updated_at) VALUES (:u, current_date, :meal, :f, 'generic', 'Pan', "
            ":unit, :ss, 100, 10, 20, 5, :q, :sv, now(), now())",
            dict(
                u=acc.id,
                f=food_id,
                meal=meal,
                unit=unit,
                ss=serving_size,
                q=quantity,
                sv=servings,
            ),
        )

    sql, p = insert()
    await run(sql, **p)
    # Sin unicidad por alimento y comida: el mismo alimento dos veces es válido (R7)
    await run(sql, **p)
    sql, p = insert(servings=2, quantity=60)
    await run(sql, **p)
    for bad in (
        insert(meal="brunch"),
        insert(unit="kg"),
        insert(quantity=0),
        insert(quantity=10000.1),
        insert(servings=0),
        insert(servings=100.5),
        insert(servings=2, serving_size=None),  # raciones sin tamaño de ración
    ):
        with pytest.raises(IntegrityError):
            await run(bad[0], **bad[1])
    with pytest.raises(IntegrityError):  # nutriente negativo
        await run("UPDATE diary_entry SET fiber_g = -1")
    await run("UPDATE diary_entry SET fiber_g = NULL")  # sin dato


async def test_0005_favoritos_y_copy_id(app, make_account, make_food, make_entry):
    """T002 (005): favorite_food con PK (user_id, food_id), FK y diary_entry.copy_id nulo."""
    from datetime import UTC, datetime

    acc = await make_account("mig-quick")
    food_id = await make_food("Pan")
    entry = await make_entry(acc, datetime.now(UTC).date(), food_id=food_id)

    async def run(sql: str, **params):
        async with app.state.engine.begin() as conn:
            return await conn.execute(text(sql), params)

    insert = "INSERT INTO favorite_food (user_id, food_id, created_at) VALUES (:u, :f, now())"
    await run(insert, u=acc.id, f=food_id)
    with pytest.raises(IntegrityError):  # PK: no se repite
        await run(insert, u=acc.id, f=food_id)
    with pytest.raises(IntegrityError):  # FK food
        await run(insert, u=acc.id, f=uuid.uuid4())
    with pytest.raises(IntegrityError):  # FK usuario
        await run(insert, u=uuid.uuid4(), f=food_id)
    row = (await run("SELECT copy_id FROM diary_entry WHERE id = :e", e=entry)).one()
    assert row.copy_id is None
    index = (
        await run("SELECT indexdef FROM pg_indexes WHERE indexname = 'ix_diary_entry_copy'")
    ).scalar_one()
    assert "copy_id IS NOT NULL" in index
