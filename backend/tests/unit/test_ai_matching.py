from decimal import Decimal

import pytest

from mykcal.ai.matching import match_items
from mykcal.ai.prompt import RawItem


@pytest.fixture
async def user(user_with_consent):
    return await user_with_consent("match-a")


def raw(name, grams=150):
    return RawItem(name=name, grams=Decimal(grams), flagged=False)


async def test_nombre_parecido_se_empareja_con_valores_de_la_base(app, user, make_food):
    account, _ = user
    await make_food("Arroz blanco cocido", kcal=130, protein_g=2.7, carbs_g=28, fat_g=0.3)
    async with app.state.sessionmaker() as s:
        (item,) = await match_items(s, account.id, [raw("Arroz blanco cocido", 150)])
    assert item.matched_food is not None and item.matched_food.name == "Arroz blanco cocido"
    assert item.kcal == 195.0 and item.carbs_g == 42.0


async def test_sin_parecido_no_empareja(app, user, make_food):
    account, _ = user
    await make_food("Arroz blanco cocido")
    async with app.state.sessionmaker() as s:
        (item,) = await match_items(s, account.id, [raw("Tarta de queso")])
    assert item.matched_food is None and item.kcal is None and item.matched_similarity is None


async def test_personalizado_ajeno_no_empareja(app, user, user_with_consent, make_food):
    a, _ = user
    b, _ = await user_with_consent("match-b")
    await make_food("Tarta secreta de B", kind="custom", owner=b)
    async with app.state.sessionmaker() as s:
        (item,) = await match_items(s, a.id, [raw("Tarta secreta de B")])
    assert item.matched_food is None
