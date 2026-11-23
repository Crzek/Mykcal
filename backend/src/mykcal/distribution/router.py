from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import FileResponse, Response

router = APIRouter()


@router.get("/descargar/mykcal.apk", include_in_schema=True)
async def download_apk(request: Request) -> Response:
    apk = Path(request.app.state.settings.apk_dir) / "mykcal.apk"
    if not apk.is_file():
        return Response(status_code=404)
    return FileResponse(
        apk,
        media_type="application/vnd.android.package-archive",
        filename="mykcal.apk",
        headers={"Cache-Control": "no-cache"},
    )
