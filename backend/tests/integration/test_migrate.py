"""Migraciones al arrancar: sin cambios no hace nada; con la base al día es idempotente."""

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
