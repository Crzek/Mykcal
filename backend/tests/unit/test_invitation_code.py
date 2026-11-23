import re

import pytest

from mykcal.invitations import codes


@pytest.mark.parametrize(
    "raw", ["abcd2345", "  ABCD2345  ", "abcd-2345", "ab cd 23 45", "AbCd\t2345"]
)
def test_normalize(raw):
    assert codes.normalize(raw) == "ABCD2345"


def test_generate_cumple_formato():
    pattern = re.compile(r"^[0-9A-HJKMNP-TV-Z]{8}$")
    for _ in range(500):
        assert pattern.match(codes.generate())


def test_generate_sin_caracteres_ambiguos():
    joined = "".join(codes.generate() for _ in range(300))
    assert not set("ILOU") & set(joined)


def test_matches():
    assert codes.matches(" abcd-2345 ", "ABCD2345")
    assert not codes.matches("ABCD2346", "ABCD2345")
    assert not codes.matches("", "ABCD2345")
