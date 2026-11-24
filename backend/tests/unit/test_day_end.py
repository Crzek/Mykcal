"""T017 (004): fin del día en UTC y objetivo vigente en un día (casos T1–T6 de summary-cases.md)."""

from datetime import UTC, date, datetime
from types import SimpleNamespace

import pytest

from mykcal.diary.day import day_end_utc, pick_target

V1 = SimpleNamespace(name="V1", effective_from=datetime(2026, 11, 10, 8, 0, tzinfo=UTC))
V2 = SimpleNamespace(name="V2", effective_from=datetime(2026, 11, 15, 22, 30, tzinfo=UTC))


def test_fin_del_dia_resta_el_desfase():
    assert day_end_utc(date(2026, 11, 12), 60) == datetime(2026, 11, 12, 23, 0, tzinfo=UTC)
    assert day_end_utc(date(2026, 11, 15), -300) == datetime(2026, 11, 16, 5, 0, tzinfo=UTC)
    assert day_end_utc(date(2026, 11, 15), 0) == datetime(2026, 11, 16, 0, 0, tzinfo=UTC)


def test_fin_del_dia_cruza_fin_de_mes_y_de_anio():
    assert day_end_utc(date(2026, 12, 31), 0) == datetime(2027, 1, 1, 0, 0, tzinfo=UTC)
    assert day_end_utc(date(2026, 2, 28), 0) == datetime(2026, 3, 1, 0, 0, tzinfo=UTC)


@pytest.mark.parametrize(
    ("day", "offset", "expected"),
    [
        (date(2026, 11, 12), 60, V1),  # T1
        (date(2026, 11, 15), 60, V2),  # T2: V2 se creó a las 23:30 locales y rige ese día
        (date(2026, 11, 15), -300, V2),  # T3
        (date(2026, 11, 15), 120, V1),  # T4: a las 22:00Z aún no existía V2
        (date(2026, 11, 9), 60, V1),  # T5: antes de V1, la más antigua
        (date(2026, 12, 1), 60, V2),  # T6: un día futuro o de hoy, la vigente
    ],
)
def test_objetivo_vigente_en_un_dia(day, offset, expected):
    versions = [V2, V1]  # el orden de entrada no importa
    assert pick_target(versions, day_end_utc(day, offset)) is expected


def test_sin_versiones_no_hay_objetivo():
    assert pick_target([], day_end_utc(date(2026, 11, 12), 60)) is None
