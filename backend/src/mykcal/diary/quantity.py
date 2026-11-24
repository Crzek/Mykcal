"""Cantidad de una entrada: g/ml o raciones (research R6). Función pura."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

from mykcal.core.errors import ApiError, ErrorCode

MAX_QUANTITY = Decimal(10000)
_ONE_DECIMAL = Decimal("0.1")


def _invalid(*fields: str) -> ApiError:
    return ApiError(400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=list(fields))


def resolve_quantity(
    quantity: Decimal | None, servings: Decimal | None, serving_size: Decimal | None
) -> tuple[Decimal, Decimal | None]:
    """Devuelve `(g/ml, raciones)` de una petición con `quantity` o `servings`, nunca los dos.

    Con raciones, la cantidad es `servings × serving_size` redondeada a 1 decimal (mitad hacia
    arriba). `serving_size` es el de la copia del alimento. Los errores son `VALIDATION_ERROR` con
    los nombres de campo.
    """
    if (quantity is None) == (servings is None):
        raise _invalid("quantity", "servings")
    if quantity is not None:
        if not 0 < quantity <= MAX_QUANTITY:
            raise _invalid("quantity")
        return quantity, None
    assert servings is not None
    if serving_size is None or servings <= 0:
        raise _invalid("servings")
    grams = (servings * serving_size).quantize(_ONE_DECIMAL, rounding=ROUND_HALF_UP)
    if not 0 < grams <= MAX_QUANTITY:
        raise _invalid("servings")
    return grams, servings
