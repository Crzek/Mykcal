from datetime import UTC, datetime, timedelta

import pytest

from mykcal.accounts.throttle import backoff_seconds, global_block_until

NOW = datetime(2026, 11, 22, 12, 0, tzinfo=UTC)


@pytest.mark.parametrize(
    "n,expected", [(1, 0), (2, 0), (3, 0), (4, 30), (5, 60), (6, 120), (20, 3600)]
)
def test_backoff(n, expected):
    assert backoff_seconds(n) == expected


def test_global_19_fallos_no_bloquea():
    failures = [NOW - timedelta(minutes=1, seconds=i) for i in range(19)]
    assert global_block_until(failures, NOW) is None


def test_global_20_fallos_bloquea_hasta_10_min_tras_el_ultimo():
    failures = [NOW - timedelta(minutes=2, seconds=i) for i in range(20)]
    last = max(failures)
    assert global_block_until(failures, NOW) == last + timedelta(minutes=10)


def test_global_fallos_antiguos_no_cuentan():
    failures = [NOW - timedelta(minutes=11, seconds=i) for i in range(30)]
    assert global_block_until(failures, NOW) is None
