"""T059 (004): rango de fechas del diario con los márgenes de R1."""

from datetime import UTC, date, datetime

import pytest

from mykcal.core.errors import ApiError, ErrorCode
from mykcal.diary.day import validate_entry_date

REGISTERED = datetime(2026, 3, 10, 23, 30, tzinfo=UTC)
NOW = datetime(2026, 11, 24, 8, 0, tzinfo=UTC)


@pytest.mark.parametrize(
    "day",
    [
        date(2026, 3, 9),  # alta − 1 día (margen de zona)
        date(2026, 3, 10),
        date(2026, 11, 24),
        date(2026, 11, 25),  # hoy + 1 día (margen de zona)
    ],
)
def test_dentro_del_rango(day):
    validate_entry_date(day, REGISTERED, NOW)


@pytest.mark.parametrize("day", [date(2026, 3, 8), date(2026, 11, 26), date(1999, 1, 1)])
def test_fuera_del_rango(day):
    with pytest.raises(ApiError) as exc:
        validate_entry_date(day, REGISTERED, NOW)
    assert exc.value.status == 400
    assert exc.value.code == ErrorCode.DIARY_DATE_OUT_OF_RANGE


def test_usa_la_fecha_utc_no_la_hora_local():
    # 23:30 UTC del día 10: la fecha UTC del alta es el 10, aunque en UTC+2 ya fuera el 11.
    with pytest.raises(ApiError):
        validate_entry_date(date(2026, 3, 8), REGISTERED, NOW)
