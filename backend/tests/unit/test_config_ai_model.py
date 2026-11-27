"""010: `AI_MODEL` como preferencia opcional separada por comas."""

from tests.unit.test_config import make


def test_preferencia_limpia_y_sin_duplicados():
    assert make(ai_model="a, b,,a").ai_model_preference == ["a", "b"]


def test_vacia_por_defecto():
    assert make().ai_model_preference == []
    assert make(ai_model="").ai_model_preference == []


def test_valor_unico_antiguo_sigue_valiendo():
    assert make(ai_model="gemini-3.6-flash").ai_model_preference == ["gemini-3.6-flash"]
