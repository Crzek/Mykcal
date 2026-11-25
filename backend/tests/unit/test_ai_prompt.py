import pytest

from mykcal.ai.prompt import AiResponseInvalid, AiUnrecognized, build_prompt, parse_response


def test_prompt_incluye_descripcion_y_gramos_si_se_dan():
    p = build_prompt("arroz con pollo", 400)
    assert "arroz con pollo" in p and "400" in p


def test_prompt_omite_lo_que_no_se_da():
    p = build_prompt(None, None)
    assert "Descripción del usuario" not in p and "pesa aproximadamente" not in p


def test_parse_valido():
    items = parse_response(
        '{"items": [{"name": "Arroz", "grams": 150}, {"name": "Pollo", "grams": 120}]}'
    )
    assert [(i.name, float(i.grams)) for i in items] == [("Arroz", 150.0), ("Pollo", 120.0)]
    assert not any(i.flagged for i in items)


def test_duplicados_se_agrupan_sumando_gramos():
    items = parse_response(
        '{"items": [{"name": "Arroz", "grams": 100}, {"name": "arroz ", "grams": 50}]}'
    )
    assert len(items) == 1 and float(items[0].grams) == 150.0


@pytest.mark.parametrize("grams", [0, 2001, -5])
def test_gramos_absurdos_quedan_marcados(grams):
    (item,) = parse_response(f'{{"items": [{{"name": "Pan", "grams": {grams}}}]}}')
    assert item.flagged


@pytest.mark.parametrize("raw", ["no json", '{"foo": 1}', '{"items": [{"name": "x"}]}', "[]", ""])
def test_respuesta_invalida(raw):
    with pytest.raises(AiResponseInvalid):
        parse_response(raw)


def test_items_vacios_es_no_reconocido():
    with pytest.raises(AiUnrecognized):
        parse_response('{"items": []}')
