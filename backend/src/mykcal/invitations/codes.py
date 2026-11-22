"""Código de invitación: generación, normalización y comparación (research R7)."""

from __future__ import annotations

import hmac
import re
import secrets

ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # Crockford, sin I L O U
CODE_LENGTH = 8
_STRIP = re.compile(r"[\s\-]+")


def normalize(raw: str) -> str:
    return _STRIP.sub("", raw).upper()


def generate() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))


def matches(candidate: str, current: str) -> bool:
    return hmac.compare_digest(normalize(candidate).encode(), current.encode())
