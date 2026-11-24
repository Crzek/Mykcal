"""Entorno de Alembic. Usa la conexión que le pasa `migrate.py` o crea la suya."""

import asyncio

from sqlalchemy.ext.asyncio import create_async_engine

from alembic import context
from mykcal.accounts import models as _accounts  # noqa: F401
from mykcal.config import get_settings
from mykcal.consent import models as _consent  # noqa: F401
from mykcal.db import Base
from mykcal.diary import models as _diary  # noqa: F401
from mykcal.foods import models as _foods  # noqa: F401
from mykcal.invitations import models as _invitations  # noqa: F401
from mykcal.profile import models as _profile  # noqa: F401
from mykcal.quick import models as _quick  # noqa: F401
from mykcal.targets import models as _targets  # noqa: F401

target_metadata = Base.metadata
config = context.config


def _run(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def _run_async():
    engine = create_async_engine(get_settings().database_url)
    async with engine.connect() as conn:
        await conn.run_sync(_run)
    await engine.dispose()


connection = config.attributes.get("connection")
if connection is not None:
    _run(connection)
else:
    asyncio.run(_run_async())
