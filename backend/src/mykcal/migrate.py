"""Migraciones al arrancar, con bloqueo consultivo. Nunca hace downgrade por su cuenta."""

from __future__ import annotations

import asyncio
import sys
import time
from pathlib import Path

from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import command
from mykcal.config import Settings, get_settings
from mykcal.logging import configure_logging, get_logger

LOCK_KEY = 0x4D594B4D  # "MYKM"
BACKEND_DIR = Path(__file__).resolve().parents[2]


def _alembic_config() -> Config:
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    return cfg


def _upgrade(connection, log) -> None:
    cfg = _alembic_config()
    cfg.attributes["connection"] = connection
    script = ScriptDirectory.from_config(cfg)
    head = script.get_current_head()
    current = MigrationContext.configure(connection).get_current_revision()
    if current == head:
        log.info("migrate_noop")
        return
    if current is not None and script.get_revision(current) is None:
        log.warning("migrate_db_ahead", from_revision=current)
        return
    start = time.monotonic()
    log.info("migrate_start", from_revision=current, to_revision=head)
    command.upgrade(cfg, "head")
    log.info(
        "migrate_done",
        from_revision=current,
        to_revision=head,
        duration_ms=int((time.monotonic() - start) * 1000),
    )


async def migrate(settings: Settings) -> None:
    log = get_logger()
    engine = create_async_engine(settings.database_url)
    try:
        async with engine.connect() as conn:
            await conn.execute(text(f"SET lock_timeout = '{int(settings.migration_timeout_s)}s'"))
            await conn.execute(text(f"SELECT pg_advisory_lock({LOCK_KEY})"))
            try:
                await conn.run_sync(_upgrade, log)
                await conn.commit()
            finally:
                await conn.rollback()
                await conn.execute(text(f"SELECT pg_advisory_unlock({LOCK_KEY})"))
                await conn.commit()
    finally:
        await engine.dispose()


def main() -> int:
    configure_logging()
    log = get_logger()
    try:
        settings = get_settings()
        asyncio.run(asyncio.wait_for(migrate(settings), settings.migration_timeout_s))
    except Exception as exc:  # noqa: BLE001
        sqlstate = getattr(getattr(exc, "orig", None), "sqlstate", None)
        log.error("migrate_failed", error_class=type(exc).__name__, sqlstate=sqlstate)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
