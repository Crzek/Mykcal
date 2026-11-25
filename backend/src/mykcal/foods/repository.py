"""Consultas de alimentos. Todo lo de los personalizados recibe `user_id` (principio V)."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import Text, and_, case, func, literal, or_, select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.foods.models import Food
from mykcal.foods.off_client import MappedProduct
from mykcal.foods.text import normalize

CANDIDATE_LIMIT = 500
SIMILARITY_THRESHOLD = "0.5"


@dataclass
class Candidate:
    food: Food
    similarity: float


def _visible_in_search(user_id: uuid.UUID):
    """Genéricos y envasados no archivados, y los personalizados propios no eliminados."""
    return or_(
        and_(Food.kind == "generic", Food.archived_at.is_(None)),
        Food.kind == "packaged",
        and_(
            Food.kind == "custom",
            Food.owner_user_id == user_id,
            Food.deleted_at.is_(None),
        ),
    )


def usable_food(user_id: uuid.UUID):
    """Alimentos que el usuario puede registrar hoy (las mismas reglas que `create_entry`)."""
    return _visible_in_search(user_id)


async def get_usable(session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID) -> Food | None:
    """El alimento si el usuario puede registrarlo hoy; ajeno, borrado o archivado: `None`."""
    stmt = select(Food).where(Food.id == food_id, usable_food(user_id))
    return (await session.execute(stmt)).scalar_one_or_none()


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


async def search(session: AsyncSession, user_id: uuid.UUID, q_norm: str) -> list[Candidate]:
    """Candidatos visibles que contienen la consulta o se le parecen (research R6).

    Devuelve hasta `CANDIDATE_LIMIT` ordenados por tipo y similitud; el orden final lo fija el
    servicio, que conoce el nombre normalizado.
    """
    await session.execute(
        text(f"SET LOCAL pg_trgm.word_similarity_threshold = {SIMILARITY_THRESHOLD}")
    )
    query = literal(q_norm, Text)
    sim = func.word_similarity(query, Food.search_text).label("sim")
    kind_rank = case({"custom": 0, "generic": 1}, value=Food.kind, else_=2)
    stmt = (
        select(Food, sim)
        .where(
            _visible_in_search(user_id),
            or_(
                Food.search_text.like(f"%{_escape_like(q_norm)}%", escape="\\"),
                query.op("<%", is_comparison=True)(Food.search_text),
            ),
        )
        .order_by(kind_rank, sim.desc())
        .limit(CANDIDATE_LIMIT)
    )
    rows = (await session.execute(stmt)).all()
    return [Candidate(food=row[0], similarity=float(row[1])) for row in rows]


async def get_visible(session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID) -> Food | None:
    """Un alimento visible para el usuario. Un personalizado ajeno o eliminado es `None`."""
    stmt = select(Food).where(
        Food.id == food_id,
        or_(
            Food.kind.in_(("generic", "packaged")),
            and_(
                Food.kind == "custom",
                Food.owner_user_id == user_id,
                Food.deleted_at.is_(None),
            ),
        ),
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def get_custom_by_barcode(
    session: AsyncSession, user_id: uuid.UUID, code: str
) -> Food | None:
    """El personalizado activo del propio usuario con ese código (US3.6)."""
    stmt = select(Food).where(
        Food.kind == "custom",
        Food.owner_user_id == user_id,
        Food.deleted_at.is_(None),
        Food.barcode == code,
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def get_packaged_by_barcode(session: AsyncSession, code: str) -> Food | None:
    """La copia local, compartida por todos los usuarios, de un producto de OFF."""
    stmt = select(Food).where(Food.kind == "packaged", Food.barcode == code)
    return (await session.execute(stmt)).scalar_one_or_none()


async def upsert_packaged(session: AsyncSession, product: MappedProduct, now: datetime) -> Food:
    """Crea o renueva la copia de un producto de OFF (clave `uq_food_packaged_barcode`)."""
    values = {
        "name": product.name,
        "brand": product.brand,
        "base_unit": product.base_unit,
        "serving_size": product.serving_size,
        "search_text": normalize(" ".join(p for p in (product.name, product.brand) if p)),
        "fetched_at": now,
        "updated_at": now,
        **product.nutrients,
    }
    stmt = insert(Food).values(
        kind="packaged",
        barcode=product.code,
        source="off",
        created_at=now,
        **values,
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[Food.barcode],
        index_where=Food.kind == "packaged",
        set_=values,
    )
    await session.execute(stmt)
    food = await get_packaged_by_barcode(session, product.code)
    assert food is not None
    await session.refresh(food)
    return food


class BarcodeTaken(Exception):
    """El usuario ya tiene un personalizado activo con ese código (`uq_food_custom_barcode`)."""


async def _get_own_custom(
    session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID
) -> Food | None:
    stmt = select(Food).where(
        Food.id == food_id,
        Food.kind == "custom",
        Food.owner_user_id == user_id,
        Food.deleted_at.is_(None),
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def _flush_or_taken(session: AsyncSession) -> None:
    try:
        await session.flush()
    except IntegrityError as exc:
        await session.rollback()
        if "uq_food_custom_barcode" in str(exc.orig):
            raise BarcodeTaken from None
        raise


async def create_custom(
    session: AsyncSession, user_id: uuid.UUID, values: dict, now: datetime
) -> Food:
    food = Food(
        id=uuid.uuid4(),
        kind="custom",
        owner_user_id=user_id,
        source="user",
        created_at=now,
        updated_at=now,
        **values,
    )
    session.add(food)
    await _flush_or_taken(session)
    return food


async def update_custom(
    session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID, values: dict, now: datetime
) -> Food | None:
    food = await _get_own_custom(session, user_id, food_id)
    if food is None:
        return None
    for key, value in values.items():
        setattr(food, key, value)
    food.updated_at = now
    await _flush_or_taken(session)
    return food


async def soft_delete_custom(
    session: AsyncSession, user_id: uuid.UUID, food_id: uuid.UUID, now: datetime
) -> bool:
    food = await _get_own_custom(session, user_id, food_id)
    if food is None:
        return False
    food.deleted_at = now
    food.updated_at = now
    await session.flush()
    return True


async def list_custom(session: AsyncSession, user_id: uuid.UUID) -> list[Food]:
    stmt = (
        select(Food)
        .where(Food.kind == "custom", Food.owner_user_id == user_id, Food.deleted_at.is_(None))
        .order_by(func.lower(Food.name), Food.name)
    )
    return list((await session.execute(stmt)).scalars())
