"""Validación del JWT de Zitadel contra el JWKS y dependencias de acceso (research R4)."""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Any

import httpx
import jwt
import structlog
from fastapi import Depends, Request
from jwt.algorithms import RSAAlgorithm
from sqlalchemy.ext.asyncio import AsyncSession

from mykcal.accounts.models import UserAccount
from mykcal.accounts.repository import get_account_by_subject
from mykcal.core.errors import ApiError, ErrorCode, unauthorized
from mykcal.db import get_session

JWKS_REFRESH_MIN_INTERVAL_S = 300
HTTP_TIMEOUT_S = 5.0
LEEWAY_S = 30


@dataclass
class Principal:
    subject: str
    token: str
    account: UserAccount | None
    is_admin: bool


def auth_unavailable() -> ApiError:
    return ApiError(
        503, ErrorCode.AUTH_UNAVAILABLE, "El servicio de acceso no responde. Inténtalo más tarde."
    )


class OidcClient:
    """Descubre el emisor, mantiene el JWKS en memoria y valida tokens."""

    def __init__(
        self,
        issuer: str,
        project_id: str,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.issuer = issuer
        self.project_id = project_id
        self.http = httpx.AsyncClient(transport=transport, timeout=HTTP_TIMEOUT_S)
        self._config: dict[str, Any] | None = None
        self._keys: dict[str, Any] = {}
        self._last_fetch = 0.0
        self._lock = asyncio.Lock()

    async def aclose(self) -> None:
        await self.http.aclose()

    async def discovery(self) -> dict[str, Any]:
        if self._config is None:
            resp = await self.http.get(f"{self.issuer}/.well-known/openid-configuration")
            resp.raise_for_status()
            self._config = resp.json()
        return self._config

    async def _refresh_keys(self) -> None:
        cfg = await self.discovery()
        resp = await self.http.get(cfg["jwks_uri"])
        resp.raise_for_status()
        keys = {}
        for jwk in resp.json().get("keys", []):
            if jwk.get("kty") == "RSA" and jwk.get("kid"):
                keys[jwk["kid"]] = RSAAlgorithm.from_jwk(jwk)
        self._keys = keys
        self._last_fetch = time.monotonic()

    async def _key_for(self, kid: str) -> Any:
        if kid in self._keys:
            return self._keys[kid]
        async with self._lock:
            if kid in self._keys:
                return self._keys[kid]
            never_loaded = not self._keys
            too_soon = time.monotonic() - self._last_fetch < JWKS_REFRESH_MIN_INTERVAL_S
            if not never_loaded and too_soon:
                return None
            try:
                await self._refresh_keys()
            except (httpx.HTTPError, KeyError, ValueError):
                self._last_fetch = time.monotonic()
                if never_loaded:
                    raise auth_unavailable() from None
                return None
            return self._keys.get(kid)

    async def verify(self, token: str) -> dict[str, Any]:
        log = structlog.get_logger("mykcal")
        try:
            header = jwt.get_unverified_header(token)
        except jwt.PyJWTError:
            log.info("auth_rejected", auth_reason="malformed")
            raise unauthorized() from None
        kid = header.get("kid")
        if header.get("alg") != "RS256" or not kid:
            log.info("auth_rejected", auth_reason="bad_header")
            raise unauthorized()
        key = await self._key_for(kid)
        if key is None:
            log.info("auth_rejected", auth_reason="unknown_kid")
            raise unauthorized()
        try:
            return jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=self.project_id,
                issuer=self.issuer,
                leeway=LEEWAY_S,
                options={"require": ["exp", "iss", "sub", "aud"]},
            )
        except jwt.ExpiredSignatureError:
            log.info("auth_rejected", auth_reason="expired")
        except jwt.InvalidAudienceError:
            log.info("auth_rejected", auth_reason="bad_audience")
        except jwt.InvalidIssuerError:
            log.info("auth_rejected", auth_reason="bad_issuer")
        except jwt.PyJWTError:
            log.info("auth_rejected", auth_reason="invalid")
        raise unauthorized()


def _bearer(request: Request) -> str:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise unauthorized()
    return token.strip()


async def get_principal(
    request: Request, session: AsyncSession = Depends(get_session)
) -> Principal:
    token = _bearer(request)
    claims = await request.app.state.oidc.verify(token)
    subject = claims["sub"]
    account = await get_account_by_subject(session, subject)
    if account is not None:
        structlog.contextvars.bind_contextvars(user_id=str(account.id))
    return Principal(
        subject=subject,
        token=token,
        account=account,
        is_admin=subject == request.app.state.settings.admin_subject,
    )


async def require_registered(principal: Principal = Depends(get_principal)) -> Principal:
    if principal.account is None:
        raise ApiError(403, ErrorCode.ACCOUNT_NOT_REGISTERED, "Aún no tienes cuenta en Mykcal.")
    return principal


async def require_active_account(principal: Principal = Depends(require_registered)) -> Principal:
    assert principal.account is not None
    if principal.account.status != "active":
        raise ApiError(403, ErrorCode.ACCOUNT_DISABLED, "Tu cuenta está desactivada.")
    return principal


async def require_admin(principal: Principal = Depends(require_active_account)) -> Principal:
    if not principal.is_admin:
        raise ApiError(403, ErrorCode.FORBIDDEN, "No tienes permiso para esto.")
    return principal
