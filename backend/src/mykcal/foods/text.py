"""Normalización de texto para la búsqueda (research R6)."""

from __future__ import annotations

import unicodedata


def normalize(s: str) -> str:
    """Minúsculas, sin tildes ni diéresis y con los espacios colapsados."""
    decomposed = unicodedata.normalize("NFKD", s)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return " ".join(stripped.casefold().split())
