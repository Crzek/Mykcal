"""010: filtro, orden, caché, evitación, presupuesto y registro del selector (sin red)."""

import uuid

import pytest
from structlog.testing import capture_logs

from mykcal.ai.fake import FakeProvider
from mykcal.ai.model_selector import (
    CATALOG_TTL_S,
    COOLDOWN_S,
    ModelSelector,
    is_economic,
    rank,
)
from mykcal.ai.provider import (
    AiKeyInvalid,
    AiNoModelAvailable,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
    ModelInfo,
)

USER = uuid.uuid4()
KEY = "clave-secreta-123"


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def _infos(*names: str, gen: bool = True) -> list[ModelInfo]:
    return [ModelInfo(n, gen) for n in names]


@pytest.mark.parametrize(
    "name", ["gemini-3.6-flash", "gemini-3.6-flash-lite", "gemini-flash-latest"]
)
def test_economicos(name):
    assert is_economic(name)


@pytest.mark.parametrize(
    "name",
    [
        "gemini-3.6-pro",
        "gemini-2.0-flash-exp",
        "gemini-3.6-flash-tts",
        "gemini-3.6-flash-image",
        "gemini-live-flash",
        "text-embedding-004",
        "gemma-3-27b-it",
    ],
)
def test_no_economicos(name):
    assert not is_economic(name)


def test_orden_lite_primero_version_descendente_y_alias_al_final():
    models = _infos(
        "gemini-2.0-flash",
        "gemini-3.5-flash",
        "gemini-flash-latest",
        "gemini-3.6-flash",
        "gemini-3.5-flash-lite",
        "gemini-3.6-flash-lite",
        "gemini-flash-lite-latest",
        "gemini-3.10-flash",
        "gemini-3.9-flash",
    )
    assert rank(models) == [
        "gemini-3.6-flash-lite",
        "gemini-3.5-flash-lite",
        "gemini-flash-lite-latest",
        "gemini-3.10-flash",
        "gemini-3.9-flash",
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-2.0-flash",
        "gemini-flash-latest",
    ]


def test_descarta_sin_generate_content():
    assert rank(_infos("gemini-3.6-flash", gen=False)) == []


def _selector(ai: FakeProvider, preference=None, clock=None) -> tuple[ModelSelector, Clock]:
    clock = clock or Clock()
    return ModelSelector(ai, preference or [], clock), clock


async def _run(sel: ModelSelector, ai: FakeProvider, key: str = KEY, total: float = 55.0):
    timeouts: list[float] = []

    async def attempt(model: str, timeout: float) -> str:
        timeouts.append(timeout)
        return await ai.analyze_photo(key, model, b"x", "p", timeout)

    out = await sel.run(USER, key, total, attempt)
    return out, timeouts


async def test_sin_preferencia_elige_lite_y_es_fallback():
    ai = FakeProvider()
    ai.models = ["gemini-3.5-flash", "gemini-3.6-flash-lite"]
    sel, _ = _selector(ai)
    out, _ = await _run(sel, ai)
    assert ai.models_tried == ["gemini-3.6-flash-lite"]
    assert out.selection == "fallback" and out.attempts == 1


async def test_listado_cacheado_24h():
    ai = FakeProvider()
    sel, clock = _selector(ai)
    await _run(sel, ai)
    await _run(sel, ai)
    assert ai.list_calls == 1
    clock.now += CATALOG_TTL_S + 1
    await _run(sel, ai)
    assert ai.list_calls == 2


async def test_claves_distintas_catalogos_separados_y_sin_hash_en_repr():
    ai = FakeProvider()
    sel, _ = _selector(ai)
    await _run(sel, ai, key="k1")
    await _run(sel, ai, key="k2")
    assert ai.list_calls == 2
    assert len(sel._catalog) == 2
    import hashlib

    for k in ("k1", "k2"):
        assert hashlib.sha256(k.encode()).hexdigest() not in repr(sel.__dict__.get("_provider"))
        assert k not in sel._catalog  # nunca la clave en claro como índice


async def test_forget_borra_su_catalogo():
    ai = FakeProvider()
    sel, _ = _selector(ai)
    await _run(sel, ai)
    sel.forget(KEY)
    await _run(sel, ai)
    assert ai.list_calls == 2


async def test_listado_falla_con_catalogo_viejo_se_usa_el_viejo():
    ai = FakeProvider()
    sel, clock = _selector(ai)
    await _run(sel, ai)
    clock.now += CATALOG_TTL_S + 1
    ai.list_outcome = "unavailable"
    with capture_logs() as logs:
        await _run(sel, ai)
    assert ai.models_tried == ["gemini-3.6-flash"] * 2
    assert any(e["event"] == "ai_model_list_failed" for e in logs)


async def test_listado_falla_sin_catalogo():
    ai = FakeProvider()
    ai.list_outcome = "unavailable"
    sel, _ = _selector(ai)
    with pytest.raises(AiProviderUnavailable):
        await _run(sel, ai)
    sel, _ = _selector(ai, ["mi-modelo"])
    out, _ = await _run(sel, ai)
    assert ai.models_tried == ["mi-modelo"] and out.selection == "preferred"


async def test_sin_modelos_compatibles():
    ai = FakeProvider()
    ai.models = ["gemini-3.6-pro"]
    sel, _ = _selector(ai)
    with pytest.raises(AiNoModelAvailable) as info:
        await _run(sel, ai)
    assert info.value.attempts == 0 and info.value.last_model is None


# --- US2 ---------------------------------------------------------------------------------


async def test_503_429_y_timeout_pasan_al_siguiente():
    for outcome in ("overloaded", "quota", "timeout"):
        ai = FakeProvider()
        ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
        ai.model_outcomes = {"gemini-3.6-flash-lite": outcome}
        sel, _ = _selector(ai)
        out, _ = await _run(sel, ai)
        assert out.model == "gemini-3.6-flash" and out.attempts == 2


async def test_evitacion_tras_503_pero_no_tras_429():
    ai = FakeProvider()
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = {"gemini-3.6-flash-lite": "overloaded"}
    sel, clock = _selector(ai)
    await _run(sel, ai)
    ai.models_tried.clear()
    clock.now += 60
    await _run(sel, ai)
    assert ai.models_tried == ["gemini-3.6-flash"]
    ai.models_tried.clear()
    clock.now += COOLDOWN_S + 1
    await _run(sel, ai)
    assert ai.models_tried[0] == "gemini-3.6-flash-lite"

    ai2 = FakeProvider()
    ai2.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai2.model_outcomes = {"gemini-3.6-flash-lite": "quota"}
    sel2, clock2 = _selector(ai2)
    await _run(sel2, ai2)
    ai2.models_tried.clear()
    clock2.now += 10
    await _run(sel2, ai2)
    assert ai2.models_tried[0] == "gemini-3.6-flash-lite"


async def test_unico_candidato_en_evitacion_se_intenta():
    ai = FakeProvider()
    ai.model_outcomes = {"gemini-3.6-flash": "overloaded"}
    sel, _ = _selector(ai)
    with pytest.raises(AiProviderUnavailable):
        await _run(sel, ai)
    ai.model_outcomes = {}
    out, _ = await _run(sel, ai)
    assert out.model == "gemini-3.6-flash"


async def test_presupuesto_por_intento():
    ai = FakeProvider()
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash", "gemini-3.5-flash"]
    sel, clock = _selector(ai)

    async def attempt(model: str, timeout: float) -> str:
        seen.append(timeout)
        clock.now += 20 if len(seen) < 3 else 0
        return await ai.analyze_photo(KEY, model, b"x", "p", timeout)

    seen: list[float] = []
    ai.model_outcomes = {"gemini-3.6-flash-lite": "timeout", "gemini-3.6-flash": "timeout"}
    out = await sel.run(USER, KEY, 45.0, attempt)
    assert seen == [20.0, 20.0, 5.0] and out.model == "gemini-3.5-flash"


async def test_sin_tiempo_restante_no_llama():
    ai = FakeProvider()
    sel, clock = _selector(ai)

    async def attempt(model: str, timeout: float) -> str:
        raise AssertionError("no debe llamarse")

    with pytest.raises(AiTimeout):
        await sel.run(USER, KEY, 0.5, attempt)


@pytest.mark.parametrize(
    ("outcomes", "expected"),
    [
        (("overloaded", "overloaded"), AiProviderUnavailable),
        (("quota", "quota"), AiQuotaExceeded),
        (("quota", "overloaded"), AiQuotaExceeded),
        (("quota", "timeout"), AiQuotaExceeded),
        (("timeout", "timeout"), AiTimeout),
        (("timeout", "overloaded"), AiTimeout),
    ],
)
async def test_error_final_el_mas_informativo(outcomes, expected):
    ai = FakeProvider()
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = dict(zip(ai.models, outcomes, strict=True))
    sel, _ = _selector(ai)
    with pytest.raises(expected):
        await _run(sel, ai)


async def test_clave_invalida_detiene_el_bucle():
    ai = FakeProvider()
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.analyze_outcome = "key_invalid"
    sel, _ = _selector(ai)
    with pytest.raises(AiKeyInvalid):
        await _run(sel, ai)
    assert len(ai.models_tried) == 1


async def test_404_refresca_el_listado_una_vez():
    ai = FakeProvider()
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = {"gemini-3.6-flash-lite": "not_found"}
    sel, _ = _selector(ai)
    out, _ = await _run(sel, ai)
    assert out.model == "gemini-3.6-flash" and ai.list_calls == 2


# --- US3 ---------------------------------------------------------------------------------


async def test_preferencia_manda_aunque_sea_pro():
    ai = FakeProvider()
    ai.models = ["gemini-3.6-pro", "gemini-3.6-flash-lite"]
    sel, _ = _selector(ai, ["gemini-3.6-pro"])
    out, _ = await _run(sel, ai)
    assert out.model == "gemini-3.6-pro" and out.selection == "preferred"


async def test_preferencia_ausente_usa_la_segunda_y_avisa_una_vez():
    ai = FakeProvider()
    ai.models = ["m-b", "gemini-3.6-flash"]
    sel, _ = _selector(ai, ["m-a", "m-b"])
    with capture_logs() as logs:
        out, _ = await _run(sel, ai)
        await _run(sel, ai)
    assert out.model == "m-b" and out.selection == "preferred"
    ignored = [e for e in logs if e["event"] == "ai_model_preference_ignored"]
    assert len(ignored) == 1 and ignored[0]["model"] == "m-a" and ignored[0]["user_id"]


async def test_ninguna_preferencia_valida_es_fallback():
    ai = FakeProvider()
    sel, _ = _selector(ai, ["m-x"])
    out, _ = await _run(sel, ai)
    assert out.selection == "fallback" and out.model == "gemini-3.6-flash"


# --- US5 ---------------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("outcome", "category"),
    [
        ("not_found", "model_not_found"),
        ("overloaded", "overloaded"),
        ("quota", "quota"),
        ("timeout", "timeout"),
    ],
)
async def test_cada_fallo_registra_su_categoria(outcome, category):
    ai = FakeProvider()
    ai.models = ["gemini-3.6-flash-lite", "gemini-3.6-flash"]
    ai.model_outcomes = {"gemini-3.6-flash-lite": outcome}
    sel, _ = _selector(ai)
    with capture_logs() as logs:
        await _run(sel, ai)
    (e,) = [e for e in logs if e["event"] == "ai_model_attempt"]
    assert e["category"] == category and e["model"] == "gemini-3.6-flash-lite"
    assert e["user_id"] == str(USER)


async def test_error_de_red_es_category_network():
    class Net(FakeProvider):
        async def analyze_photo(self, raw_key, model, image, prompt, timeout_s):
            raise AiProviderUnavailable

    ai = Net()
    sel, _ = _selector(ai)
    with capture_logs() as logs, pytest.raises(AiProviderUnavailable):
        await _run(sel, ai)
    assert [e["category"] for e in logs if e["event"] == "ai_model_attempt"] == ["network"]
