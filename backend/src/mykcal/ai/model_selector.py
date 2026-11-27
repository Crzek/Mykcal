"""Selección del modelo de IA en tiempo de ejecución (010).

Pregunta al proveedor qué modelos ve la clave, ordena los candidatos y los prueba dentro del
presupuesto total. Estado solo en memoria; la clave nunca se guarda ni se registra: se indexa por
su hash y el hash tampoco se registra.
"""

from __future__ import annotations

import asyncio
import hashlib
import re
import time
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any

from mykcal.ai.provider import (
    AiKeyInvalid,
    AiModelNotFound,
    AiNoModelAvailable,
    AiProvider,
    AiProviderUnavailable,
    AiQuotaExceeded,
    AiTimeout,
    ModelInfo,
)
from mykcal.logging import get_logger

CATALOG_TTL_S = 86400.0
COOLDOWN_S = 180.0
PER_MODEL_TIMEOUT_S = 20.0
LIST_TIMEOUT_S = 10.0
MIN_ATTEMPT_S = 1.0

_EXCLUDED = frozenset(
    {
        "exp",
        "tts",
        "image",
        "live",
        "audio",
        "embedding",
        "robotics",
        "computer",
        "pro",
        "ultra",
    }
)
_VERSION = re.compile(r"^gemini-(\d+)(?:\.(\d+))?-flash")


def is_economic(name: str) -> bool:
    """`gemini-…flash…` sin variantes experimentales, de otra modalidad ni `pro`/`ultra`."""
    if not name.startswith("gemini-") or "flash" not in name:
        return False
    return not (set(name.split("-")) & _EXCLUDED)


def _sort_key(name: str) -> tuple[int, int, int, int]:
    # menor = antes. Grupo 0 = lite; los alias sin versión van al final de su grupo.
    group = 0 if "lite" in name else 1
    m = _VERSION.match(name)
    if m is None:
        return (group, 1, 0, 0)
    return (group, 0, -int(m.group(1)), -int(m.group(2) or 0))


def rank(models: list[ModelInfo]) -> list[str]:
    """Candidatos automáticos: lite antes que flash, versión descendente, nombre inverso."""
    names = [m.name for m in models if m.generate_content and is_economic(m.name)]
    names.sort(reverse=True)  # desempate: nombre inverso (el segundo orden es estable)
    names.sort(key=_sort_key)
    return names


@dataclass(frozen=True)
class SelectionOutcome:
    text: str
    model: str
    selection: str  # "preferred" | "fallback"
    attempts: int


@dataclass
class _Entry:
    fetched_at: float
    models: list[ModelInfo]


def _category(exc: Exception) -> tuple[str, int | None]:
    if isinstance(exc, AiModelNotFound):
        return "model_not_found", 404
    if isinstance(exc, AiQuotaExceeded):
        return "quota", 429
    if isinstance(exc, AiTimeout):
        return "timeout", None
    if isinstance(exc, AiKeyInvalid):
        return "key_invalid", None
    if isinstance(exc, AiProviderUnavailable) and exc.overloaded:
        return "overloaded", 503
    return "network", None


class ModelSelector:
    def __init__(
        self,
        provider: AiProvider,
        preference: list[str],
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._provider = provider
        self._preference = list(preference)
        self._clock = clock
        self._catalog: dict[str, _Entry] = {}
        self._cooldown: dict[tuple[str, str], float] = {}
        self._locks: dict[str, asyncio.Lock] = {}

    @staticmethod
    def _hash(raw_key: str) -> str:
        return hashlib.sha256(raw_key.encode()).hexdigest()

    def forget(self, raw_key: str) -> None:
        key_hash = self._hash(raw_key)
        self._catalog.pop(key_hash, None)
        for k in [k for k in self._cooldown if k[0] == key_hash]:
            del self._cooldown[k]

    # --- catálogo -------------------------------------------------------------------------

    async def _fetch(
        self, user_id: uuid.UUID, raw_key: str, key_hash: str, deadline: float
    ) -> list[ModelInfo]:
        remaining = deadline - self._clock()
        if remaining < MIN_ATTEMPT_S:
            raise AiTimeout
        models = await self._provider.list_models(raw_key, min(LIST_TIMEOUT_S, remaining))
        usable = [m for m in models if m.generate_content]
        now = self._clock()
        self._catalog[key_hash] = _Entry(now, usable)
        for h in [h for h, e in self._catalog.items() if now - e.fetched_at > 2 * CATALOG_TTL_S]:
            del self._catalog[h]
        names = {m.name for m in usable}
        for name in self._preference:
            if name not in names:
                get_logger().warning(
                    "ai_model_preference_ignored", user_id=str(user_id), model=name
                )
        return usable

    async def _models_for(
        self,
        user_id: uuid.UUID,
        raw_key: str,
        key_hash: str,
        deadline: float,
        *,
        force: bool = False,
    ) -> list[ModelInfo] | None:
        """Catálogo vigente; el viejo si el listado falla; None si no hay (y hay preferencia)."""
        lock = self._locks.setdefault(key_hash, asyncio.Lock())
        async with lock:
            entry = self._catalog.get(key_hash)
            if entry and not force and self._clock() - entry.fetched_at < CATALOG_TTL_S:
                return entry.models
            try:
                return await self._fetch(user_id, raw_key, key_hash, deadline)
            except AiKeyInvalid:
                raise
            except (AiProviderUnavailable, AiTimeout, AiQuotaExceeded) as exc:
                category, status = _category(exc)
                fields: dict[str, Any] = {"status": status} if status else {}
                get_logger().warning(
                    "ai_model_list_failed", user_id=str(user_id), category=category, **fields
                )
                if entry is not None:
                    return entry.models
                if self._preference:
                    return None
                raise

    def _candidates(
        self, key_hash: str, models: list[ModelInfo] | None, tried: set[str]
    ) -> list[str]:
        if models is None:  # sin listado ni catálogo: la preferencia tal cual
            ordered = list(self._preference)
        else:
            names = {m.name for m in models}
            ordered = [p for p in self._preference if p in names]
            ordered += [n for n in rank(models) if n not in ordered]
        ordered = [n for n in ordered if n not in tried]
        now = self._clock()
        for k in [k for k, until in self._cooldown.items() if until <= now]:
            del self._cooldown[k]
        fresh = [n for n in ordered if (key_hash, n) not in self._cooldown]
        return fresh + [n for n in ordered if (key_hash, n) in self._cooldown]

    # --- ejecución ------------------------------------------------------------------------

    async def run(
        self,
        user_id: uuid.UUID,
        raw_key: str,
        total_timeout_s: float,
        attempt: Callable[[str, float], Awaitable[str]],
    ) -> SelectionOutcome:
        state: dict[str, Any] = {"model": None, "attempts": 0}
        try:
            return await self._run(user_id, raw_key, total_timeout_s, attempt, state)
        except Exception as exc:
            exc.last_model = state["model"]  # type: ignore[attr-defined]
            exc.attempts = state["attempts"]  # type: ignore[attr-defined]
            raise

    async def _run(
        self,
        user_id: uuid.UUID,
        raw_key: str,
        total_timeout_s: float,
        attempt: Callable[[str, float], Awaitable[str]],
        state: dict[str, Any],
    ) -> SelectionOutcome:
        key_hash = self._hash(raw_key)
        deadline = self._clock() + total_timeout_s
        models = await self._models_for(user_id, raw_key, key_hash, deadline)
        tried: set[str] = set()
        failures: list[Exception] = []
        refreshed = False
        while True:
            candidates = self._candidates(key_hash, models, tried)
            if not candidates:
                break
            remaining = deadline - self._clock()
            if remaining < MIN_ATTEMPT_S:
                failures.append(AiTimeout())
                break
            model = candidates[0]
            tried.add(model)
            state["model"] = model
            state["attempts"] += 1
            try:
                text = await attempt(model, min(PER_MODEL_TIMEOUT_S, remaining))
            except AiKeyInvalid:
                raise
            except (AiModelNotFound, AiProviderUnavailable, AiQuotaExceeded, AiTimeout) as exc:
                category, status = _category(exc)
                fields: dict[str, Any] = {"status": status} if status else {}
                get_logger().warning(
                    "ai_model_attempt",
                    user_id=str(user_id),
                    model=model,
                    category=category,
                    **fields,
                )
                if isinstance(exc, AiModelNotFound):
                    if models is not None:
                        models = [m for m in models if m.name != model]
                        entry = self._catalog.get(key_hash)
                        if entry is not None:
                            entry.models = models
                    if not refreshed:
                        refreshed = True
                        fresh = await self._models_for(
                            user_id, raw_key, key_hash, deadline, force=True
                        )
                        if fresh is not None:
                            models = fresh
                    continue
                if category == "overloaded":
                    self._cooldown[(key_hash, model)] = self._clock() + COOLDOWN_S
                failures.append(exc)
                continue
            selection = "preferred" if model in self._preference else "fallback"
            return SelectionOutcome(text, model, selection, state["attempts"])
        for kind in (AiQuotaExceeded, AiTimeout, AiProviderUnavailable):
            for f in failures:
                if isinstance(f, kind):
                    raise f
        raise AiNoModelAvailable
