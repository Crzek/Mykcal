"""Cliente de Open Food Facts y mapeo de su respuesta a nuestros nutrientes (research R7, R8)."""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation
from typing import Any, Literal

import httpx

from mykcal.foods.nutrients import MAX_PER_100, NUTRIENTS, REQUIRED_NUTRIENTS

FIELDS = (
    "code,product_name,product_name_es,brands,nutriments,serving_quantity,"
    "serving_quantity_unit,product_quantity_unit"
)
NO_NAME = "Producto sin nombre"
KJ_PER_KCAL = Decimal("4.184")
_TWO_DECIMALS = Decimal("0.01")
_ML_UNITS = ("ml", "cl", "l")

# (campo de OFF, nutriente nuestro, factor). OFF da gramos; nosotros mg o µg (R8).
_CONVERSIONS: tuple[tuple[str, str, Decimal], ...] = (
    ("proteins_100g", "protein_g", Decimal(1)),
    ("carbohydrates_100g", "carbs_g", Decimal(1)),
    ("fat_100g", "fat_g", Decimal(1)),
    ("fiber_100g", "fiber_g", Decimal(1)),
    ("sodium_100g", "sodium_mg", Decimal(1000)),
    ("potassium_100g", "potassium_mg", Decimal(1000)),
    ("calcium_100g", "calcium_mg", Decimal(1000)),
    ("iron_100g", "iron_mg", Decimal(1000)),
    ("magnesium_100g", "magnesium_mg", Decimal(1000)),
    ("vitamin-d_100g", "vitamin_d_ug", Decimal(1_000_000)),
    ("vitamin-c_100g", "vitamin_c_mg", Decimal(1000)),
)


class OffUnavailable(Exception):
    """Sin red, tiempo agotado, 5xx o respuesta ilegible."""


@dataclass(frozen=True)
class MappedProduct:
    code: str
    name: str
    brand: str | None
    base_unit: Literal["g", "ml"]
    nutrients: dict[str, Decimal | None]
    serving_size: Decimal | None


@dataclass(frozen=True)
class OffResult:
    status: Literal["found", "incomplete", "not_found"]
    product: MappedProduct | None = None
    # Solo con `incomplete`: para precargar el formulario del personalizado (US2.4).
    name: str | None = None
    brand: str | None = None
    extra: dict[str, Any] = field(default_factory=dict)


def _decimal(value: Any) -> Decimal | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = Decimal(str(value).strip().replace(",", "."))
    except InvalidOperation:
        return None
    return number if number.is_finite() else None


def _round(value: Decimal) -> Decimal:
    return value.quantize(_TWO_DECIMALS, rounding=ROUND_HALF_UP)


def _in_range(name: str, value: Decimal) -> bool:
    return Decimal(0) <= value <= MAX_PER_100[name]


def _nutrients(raw: dict[str, Any]) -> dict[str, Decimal | None]:
    out: dict[str, Decimal | None] = {name: None for name in NUTRIENTS}
    kcal = _decimal(raw.get("energy-kcal_100g"))
    if kcal is None:
        kj = _decimal(raw.get("energy-kj_100g"))
        kcal = None if kj is None else kj / KJ_PER_KCAL
    out["kcal"] = None if kcal is None else _round(kcal)
    for source, target, factor in _CONVERSIONS:
        value = _decimal(raw.get(source))
        out[target] = None if value is None else _round(value * factor)
    # Un valor imposible se trata como ausente: así no rompe las restricciones de la tabla.
    for name, value in out.items():
        if value is not None and not _in_range(name, value):
            out[name] = None
    return out


def _clean(text: Any, limit: int) -> str | None:
    if not isinstance(text, str):
        return None
    text = text.strip()
    return text[:limit].strip() or None if text else None


def _brand(product: dict[str, Any]) -> str | None:
    brands = product.get("brands")
    if not isinstance(brands, str):
        return None
    return _clean(brands.split(",")[0], 80)


def map_product(payload: dict[str, Any]) -> OffResult:
    """Función pura: respuesta de OFF → `found`, `incomplete` o `not_found` (R7, R8)."""
    product = payload.get("product")
    if payload.get("status") != 1 or not isinstance(product, dict):
        return OffResult("not_found")
    raw = product.get("nutriments")
    nutrients = _nutrients(raw if isinstance(raw, dict) else {})
    name = _clean(product.get("product_name_es"), 120) or _clean(product.get("product_name"), 120)
    brand = _brand(product)
    if any(nutrients[n] is None for n in REQUIRED_NUTRIENTS):
        return OffResult("incomplete", name=name, brand=brand)
    unit = str(product.get("product_quantity_unit") or "").strip().lower()
    serving = _decimal(product.get("serving_quantity"))
    if serving is not None:
        serving = _round(serving)
        if not Decimal(0) < serving <= Decimal(5000):
            serving = None
    return OffResult(
        "found",
        product=MappedProduct(
            code=str(payload.get("code") or product.get("code") or ""),
            name=name or NO_NAME,
            brand=brand,
            base_unit="ml" if unit in _ML_UNITS else "g",
            nutrients=nutrients,
            serving_size=serving,
        ),
    )


class OffClient:
    """`GET {base}/api/v2/product/{code}` sin reintentos y con transporte inyectable (R7)."""

    def __init__(
        self,
        base_url: str,
        user_agent: str,
        timeout_s: float,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._http = httpx.AsyncClient(
            transport=transport,
            timeout=timeout_s,
            headers={"User-Agent": user_agent},
        )

    async def aclose(self) -> None:
        await self._http.aclose()

    async def fetch(self, code: str) -> OffResult:
        try:
            resp = await self._http.get(
                f"{self._base_url}/api/v2/product/{code}", params={"fields": FIELDS}
            )
        except httpx.HTTPError as exc:
            raise OffUnavailable("Open Food Facts no responde") from exc
        if resp.status_code == 404:
            return OffResult("not_found")
        if resp.status_code != 200:
            raise OffUnavailable(f"Open Food Facts respondió {resp.status_code}")
        try:
            payload = resp.json()
        except ValueError as exc:
            raise OffUnavailable("respuesta ilegible de Open Food Facts") from exc
        if not isinstance(payload, dict):
            raise OffUnavailable("respuesta inesperada de Open Food Facts")
        return map_product(payload)
