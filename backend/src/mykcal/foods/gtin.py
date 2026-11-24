"""Validación y normalización de códigos de barras GTIN (research R9)."""

from __future__ import annotations

VALID_LENGTHS = (8, 12, 13, 14)


def is_valid_gtin(code: str) -> bool:
    if not code.isascii() or not code.isdigit() or len(code) not in VALID_LENGTHS:
        return False
    body, check = code[:-1], int(code[-1])
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(body)))
    return (10 - total % 10) % 10 == check


def normalize_gtin(code: str) -> str:
    """Devuelve la clave canónica: un UPC-A de 12 dígitos pasa a EAN-13 con un 0 delante."""
    code = code.strip()
    if not is_valid_gtin(code):
        raise ValueError("código de barras no válido")
    return "0" + code if len(code) == 12 else code
