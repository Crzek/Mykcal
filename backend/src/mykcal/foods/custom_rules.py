"""Reglas puras de los alimentos personalizados (research R10, FR-013, FR-014)."""

from __future__ import annotations

from collections.abc import Mapping
from decimal import ROUND_HALF_UP, Decimal

from mykcal.foods.gtin import is_valid_gtin
from mykcal.foods.nutrients import MAX_PER_100, NUTRIENTS
from mykcal.foods.schemas import CustomFoodInput

NAME_MAX = 120
BRAND_MAX = 80
SERVING_MAX = Decimal(5000)
MISMATCH_TOLERANCE = Decimal("0.15")
_TWO_DECIMALS = Decimal("0.01")
_MASS_FIELDS = ("protein_g", "carbs_g", "fat_g", "fiber_g")


def _round(value: Decimal) -> Decimal:
    return value.quantize(_TWO_DECIMALS, rounding=ROUND_HALF_UP)


def to_per_100(data: CustomFoodInput) -> dict[str, Decimal | None]:
    """Valores por 100 g o ml. Con `per_serving`: `valor × 100 / ración` (FR-013)."""
    raw = data.values.model_dump()
    if data.basis == "per_serving" and data.serving_size:
        factor = Decimal(100) / data.serving_size
    else:
        factor = Decimal(1)
    return {
        name: None if raw[name] is None else _round(Decimal(raw[name]) * factor)
        for name in NUTRIENTS
    }


def validate(data: CustomFoodInput) -> list[str]:
    """Nombres de los campos inválidos, nunca sus valores. Lista vacía si todo está bien."""
    bad: list[str] = []

    def add(*names: str) -> None:
        for name in names:
            if name not in bad:
                bad.append(name)

    name = data.name.strip()
    if not name or len(name) > NAME_MAX:
        add("name")
    if data.brand is not None and len(data.brand.strip()) > BRAND_MAX:
        add("brand")
    if data.barcode is not None and not is_valid_gtin(data.barcode.strip()):
        add("barcode")
    serving = data.serving_size
    if serving is not None and not Decimal(0) < serving <= SERVING_MAX:
        add("serving_size")
    if data.basis == "per_serving" and serving is None:
        add("serving_size")

    raw = data.values.model_dump()
    for field, value in raw.items():
        if value is not None and Decimal(value) < 0:
            add(field)
    if "serving_size" in bad and data.basis == "per_serving":
        return bad  # sin ración válida no se puede convertir

    per_100 = to_per_100(data)
    for field, value in per_100.items():
        if value is not None and not Decimal(0) <= value <= MAX_PER_100[field]:
            add(field)
    # La fibra cuenta: en CIQUAL y en OFF no forma parte de los carbohidratos (R10).
    total = sum((per_100[f] or Decimal(0) for f in _MASS_FIELDS), Decimal(0))
    if total > 100:
        add(*_MASS_FIELDS)
    return bad


def kcal_mismatch(per_100: Mapping[str, Decimal | None]) -> bool:
    """`True` si las kcal difieren de `4P + 4C + 9G` en más de un 15 % (aviso, no bloquea)."""
    kcal = per_100["kcal"] or Decimal(0)
    calculated = (
        4 * (per_100["protein_g"] or Decimal(0))
        + 4 * (per_100["carbs_g"] or Decimal(0))
        + 9 * (per_100["fat_g"] or Decimal(0))
    )
    if calculated == 0:
        return kcal > 0
    return abs(kcal - calculated) / calculated > MISMATCH_TOLERANCE
