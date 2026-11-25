"""App FastAPI. Arranque: `uvicorn mykcal.main:create_app --factory`."""

from __future__ import annotations

import time
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
import structlog
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import text

from mykcal.accounts.router import router as accounts_router
from mykcal.ai.gemini import GeminiProvider
from mykcal.ai.provider import AiProvider
from mykcal.ai.router import router as ai_router
from mykcal.config import Settings, get_settings
from mykcal.consent.router import router as consent_router
from mykcal.core.auth import OidcClient
from mykcal.core.errors import ApiError, ErrorCode
from mykcal.db import make_engine, make_sessionmaker
from mykcal.diary.router import router as diary_router
from mykcal.distribution.router import router as distribution_router
from mykcal.foods.router import router as foods_router
from mykcal.invitations.router import router as invitations_router
from mykcal.logging import configure_logging, get_logger
from mykcal.profile.router import router as profile_router
from mykcal.quick.router import router as quick_router
from mykcal.targets.router import router as targets_router
from mykcal.weight.router import router as weight_router

# Única lista de rutas sin identidad (principio V, Complexity Tracking del plan).
PUBLIC_ROUTES = {("GET", "/v1/health"), ("GET", "/descargar/mykcal.apk")}


def create_app(
    settings: Settings | None = None,
    oidc_transport: httpx.AsyncBaseTransport | None = None,
    off_transport: httpx.AsyncBaseTransport | None = None,
    ai_provider: AiProvider | None = None,
) -> FastAPI:
    configure_logging()
    settings = settings or get_settings()
    engine = make_engine(settings.database_url)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        yield
        await app.state.oidc.aclose()
        await engine.dispose()

    app = FastAPI(
        title="Mykcal API",
        version="0.1.0",
        lifespan=lifespan,
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    app.state.settings = settings
    app.state.engine = engine
    app.state.sessionmaker = make_sessionmaker(engine)
    app.state.off_transport = off_transport
    app.state.ai_provider = ai_provider or GeminiProvider(settings.ai_model, settings.ai_timeout_s)
    app.state.oidc = OidcClient(settings.oidc_issuer, settings.oidc_project_id, oidc_transport)

    @app.middleware("http")
    async def access_log(request: Request, call_next):
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=uuid.uuid4().hex[:12])
        start = time.monotonic()
        response = await call_next(request)
        get_logger().info(
            "request",
            method=request.method,
            # La plantilla de la ruta (`/v1/diary/days/{date}`), no la URL: la fecha de un día del
            # diario y los ids de entrada no deben quedar en los registros (principio X, R12).
            path=getattr(request.scope.get("route"), "path", request.url.path),
            status=response.status_code,
            duration_ms=int((time.monotonic() - start) * 1000),
        )
        return response

    @app.exception_handler(ApiError)
    async def _api_error(_: Request, exc: ApiError) -> JSONResponse:
        get_logger().info("api_error", error_code=exc.code.value, status=exc.status)
        return JSONResponse(exc.body(), status_code=exc.status, headers=exc.headers)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        # Solo los nombres de campo: nunca `input` ni el mensaje, que pueden llevar el valor.
        fields: list[str] = []
        for item in exc.errors():
            name = next((str(p) for p in reversed(item["loc"]) if isinstance(p, str)), None)
            if name and name not in ("body", "query") and name not in fields:
                fields.append(name)
        err = ApiError(
            400, ErrorCode.VALIDATION_ERROR, "Petición no válida.", fields=fields or None
        )
        return JSONResponse(err.body(), status_code=400)

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
        get_logger().error("unhandled_error", error_class=type(exc).__name__)
        err = ApiError(500, ErrorCode.INTERNAL_ERROR, "Error interno del servidor.")
        return JSONResponse(err.body(), status_code=500)

    @app.get("/v1/health")
    async def health() -> JSONResponse:
        try:
            async with app.state.sessionmaker() as session:
                await session.execute(text("SELECT 1"))
        except Exception as exc:  # noqa: BLE001
            get_logger().error("unhandled_error", error_class=type(exc).__name__)
            err = ApiError(503, ErrorCode.INTERNAL_ERROR, "La base de datos no responde.")
            return JSONResponse(err.body(), status_code=503)
        return JSONResponse({"status": "ok"})

    app.include_router(accounts_router)
    app.include_router(invitations_router)
    app.include_router(distribution_router)
    app.include_router(consent_router)
    app.include_router(profile_router)
    app.include_router(targets_router)
    # El de `quick` va antes: `/v1/foods/recent` no debe caer en `/v1/foods/{food_id}` (R10).
    app.include_router(quick_router)
    app.include_router(foods_router)
    app.include_router(diary_router)
    app.include_router(ai_router)
    app.include_router(weight_router)
    return app
