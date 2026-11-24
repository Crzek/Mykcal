import pytest

from mykcal.foods.gtin import is_valid_gtin, normalize_gtin


def _with_check(body: str) -> str:
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(body)))
    return body + str((10 - total % 10) % 10)


@pytest.mark.parametrize("body", ["1234567", "12345678901", "841000000000", "1234567890123"])
def test_acepta_longitudes_validas(body):
    code = _with_check(body)
    assert is_valid_gtin(code)


def test_ean13_conocido():
    assert is_valid_gtin("4006381333931")
    assert is_valid_gtin("5449000000996")


@pytest.mark.parametrize(
    "code",
    ["", "1234567", "123456789", "12345678901234567", "abcdefgh", "4006381333932", "40063813339 1"],
)
def test_rechaza(code):
    assert not is_valid_gtin(code)


def test_digito_de_control_erroneo():
    with pytest.raises(ValueError):
        normalize_gtin("4006381333932")


def test_upca_se_normaliza_a_ean13():
    upc = _with_check("03600029145")  # 12 dígitos
    assert len(upc) == 12
    assert normalize_gtin(upc) == "0" + upc
    assert normalize_gtin("0" + upc) == "0" + upc


def test_ean8_y_gtin14_no_cambian():
    ean8 = _with_check("1234567")
    gtin14 = _with_check("1234567890123")
    assert normalize_gtin(ean8) == ean8
    assert normalize_gtin(gtin14) == gtin14


def test_quita_espacios_alrededor():
    assert normalize_gtin(" 4006381333931 ") == "4006381333931"
