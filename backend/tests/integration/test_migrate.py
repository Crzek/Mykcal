"""Migraciones al arrancar: sin cambios no hace nada; con la base al día es idempotente."""

from mykcal.migrate import migrate


async def test_migrar_con_la_base_al_dia_es_noop(settings, migrated, capsys):
    capsys.readouterr()
    await migrate(settings)
    out = capsys.readouterr().out
    assert "migrate_noop" in out
    assert "migrate_start" not in out
