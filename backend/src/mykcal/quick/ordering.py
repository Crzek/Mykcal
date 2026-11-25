"""Orden de la pestaña de favoritos (FR-010). Función pura."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime
from typing import Protocol

from mykcal.foods.text import normalize


class _Favorite(Protocol):
    name: str
    last_used_at: datetime | None


def order_favorites[F: _Favorite](items: Iterable[F]) -> list[F]:
    """Último uso descendente; los nunca usados al final por nombre (sin tildes ni mayúsculas).

    Empates de uso, por el mismo nombre normalizado.
    """
    items = list(items)
    used = [i for i in items if i.last_used_at is not None]
    never = [i for i in items if i.last_used_at is None]
    used.sort(key=lambda i: (-i.last_used_at.timestamp(), normalize(i.name)))  # type: ignore[union-attr]
    never.sort(key=lambda i: normalize(i.name))
    return used + never
