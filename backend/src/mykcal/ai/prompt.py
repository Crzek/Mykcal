"""Prompt y validación de la respuesta de la IA (research R6). Funciones puras."""

from __future__ import annotations

import json
from dataclasses import dataclass
from decimal import Decimal

from pydantic import BaseModel, Field, ValidationError

from mykcal.foods.text import normalize

MAX_SANE_GRAMS = 2000


class AiResponseInvalid(Exception):
    """La respuesta no es JSON o no cumple el esquema."""


class AiUnrecognized(Exception):
    """La IA no reconoció ningún alimento."""


class _Item(BaseModel):
    name: str = Field(min_length=1)
    grams: float


class _Result(BaseModel):
    items: list[_Item]


@dataclass
class RawItem:
    name: str
    grams: Decimal
    flagged: bool


def build_prompt(description: str | None, total_grams: int | None) -> str:
    parts = [
        "Analiza la foto de un plato de comida. Identifica cada alimento visible y estima los "
        "gramos de cada uno. Usa nombres genéricos en español (por ejemplo «Arroz blanco "
        "cocido»). Responde SOLO con un JSON de la forma "
        '{"items": [{"name": "…", "grams": 0}]}. No incluyas calorías ni otro texto.'
    ]
    if description:
        parts.append(f"Descripción del usuario: {description}")
    if total_grams:
        parts.append(f"El plato pesa aproximadamente {total_grams} g en total.")
    return "\n".join(parts)


def parse_response(raw: str) -> list[RawItem]:
    try:
        result = _Result.model_validate(json.loads(raw))
    except (ValueError, ValidationError) as exc:
        raise AiResponseInvalid from exc
    grouped: dict[str, RawItem] = {}
    for item in result.items:
        key = normalize(item.name)
        grams = Decimal(str(item.grams))
        if key in grouped:
            grouped[key].grams += grams
        else:
            grouped[key] = RawItem(name=item.name.strip(), grams=grams, flagged=False)
    if not grouped:
        raise AiUnrecognized
    for it in grouped.values():
        it.flagged = it.grams <= 0 or it.grams > MAX_SANE_GRAMS
    return list(grouped.values())
