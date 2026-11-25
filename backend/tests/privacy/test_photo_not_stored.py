"""T039 (006): FR-012, SC-003. La foto no se guarda en ningún sitio del servidor."""

import os
import tempfile
from pathlib import Path

import pytest
from sqlalchemy import text

pytestmark = pytest.mark.privacy

MARK = b"\xff\xd8\xff-MARCA-UNICA-DE-LA-FOTO-" + os.urandom(16)
PHOTO = MARK + b"x" * (2 * 1024 * 1024)  # mayor que el umbral de 1 MB de Starlette


async def send(client, h):
    return await client.post(
        "/v1/photo-analysis",
        headers=h,
        files={"photo": ("p.jpg", PHOTO, "image/jpeg")},
        data={"meal": "lunch", "entry_date": "2026-01-01"},
    )


def tmp_has_photo() -> bool:
    for path in Path(tempfile.gettempdir()).rglob("*"):
        try:
            if path.is_file() and path.stat().st_size >= len(MARK) and MARK in path.read_bytes():
                return True
        except OSError:
            continue
    return False


async def test_la_foto_no_queda_en_disco_ni_en_la_base(app, client, user_with_consent, ai):
    _, h = await user_with_consent("photo-priv")
    await client.put("/v1/ai-key", headers=h, json={"raw_key": "k"})
    for outcome in ("success", "timeout"):
        ai.analyze_outcome = outcome
        await send(client, h)
        assert not tmp_has_photo()
    async with app.state.sessionmaker() as s:
        tables = (
            await s.execute(text("SELECT tablename FROM pg_tables WHERE schemaname='public'"))
        ).scalars()
        for table in tables:
            dump = (await s.execute(text(f'SELECT t::text FROM "{table}" t'))).scalars().all()
            assert not any("MARCA-UNICA" in row for row in dump), table
