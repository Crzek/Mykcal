"""Emparejamiento de lo que ve la IA con la base de alimentos (research R7).

Los valores nutricionales salen siempre del alimento emparejado (principio II).
"""

from __future__ import annotations

import uuid
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.ai.prompt import RawItem
from mykcal.ai.schemas import ProposedItem
from mykcal.foods import repository
from mykcal.foods.service import to_summary
from mykcal.foods.text import normalize

MATCH_THRESHOLD = 0.5
_ONE_DECIMAL = Decimal("0.1")


def _scaled(per_100: Decimal | None, grams: Decimal) -> float | None:
    if per_100 is None:
        return None
    return float((Decimal(per_100) * grams / 100).quantize(_ONE_DECIMAL, rounding=ROUND_HALF_UP))


async def match_items(
    session: AsyncSession, user_id: uuid.UUID, raw_items: list[RawItem]
) -> list[ProposedItem]:
    out: list[ProposedItem] = []
    for raw in raw_items:
        candidates = await repository.search(session, user_id, normalize(raw.name))
        best = max(candidates, key=lambda c: c.similarity, default=None)
        base = {"ai_name": raw.name, "ai_grams": float(raw.grams), "flagged": raw.flagged}
        if best is None or best.similarity < MATCH_THRESHOLD:
            out.append(ProposedItem(**base))
            continue
        food = best.food
        out.append(
            ProposedItem(
                **base,
                matched_food=to_summary(food, user_id),
                matched_similarity=round(best.similarity, 3),
                kcal=_scaled(food.kcal, raw.grams),
                protein_g=_scaled(food.protein_g, raw.grams),
                carbs_g=_scaled(food.carbs_g, raw.grams),
                fat_g=_scaled(food.fat_g, raw.grams),
            )
        )
    return out
