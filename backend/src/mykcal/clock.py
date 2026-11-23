"""Reloj inyectable: las pruebas lo sustituyen para controlar el tiempo."""

from __future__ import annotations

from datetime import UTC, datetime


def utcnow() -> datetime:
    return datetime.now(UTC)
