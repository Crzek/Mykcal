"""Fixtures: PostgreSQL con testcontainers, Zitadel simulado y cliente de la app."""

from __future__ import annotations

import time
import uuid
from collections.abc import AsyncIterator
from datetime import UTC, datetime
from pathlib import Path

import httpx
import jwt
import pytest
import pytest_asyncio
import yaml
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm
from sqlalchemy import text
from testcontainers.community.postgres import PostgresContainer

from mykcal.accounts.models import UserAccount
from mykcal.config import Settings
from mykcal.main import create_app
from mykcal.migrate import migrate

ISSUER = "https://zitadel.test"
PROJECT_ID = "proj-1"
ADMIN_SUB = "admin-sub"
SPEC_PATH = (
    Path(__file__).resolve().parents[2] / "specs/001-acceso-y-despliegue/contracts/openapi.yaml"
)

_KEYS: dict[str, rsa.RSAPrivateKey] = {}


def _key(name: str) -> rsa.RSAPrivateKey:
    if name not in _KEYS:
        _KEYS[name] = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return _KEYS[name]


class FakeZitadel:
    """Zitadel simulado: discovery, JWKS y userinfo servidos con MockTransport."""

    def __init__(self) -> None:
        self.published = {"k1": _key("k1")}
        self.jwks_calls = 0
        self.discovery_calls = 0
        self.userinfo_calls = 0
        self.jwks_down = False
        self.userinfo_down = False
        self.names: dict[str, str] = {}

    @property
    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self._handle)

    def _handle(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == "/.well-known/openid-configuration":
            self.discovery_calls += 1
            return httpx.Response(
                200,
                json={
                    "issuer": ISSUER,
                    "jwks_uri": f"{ISSUER}/oauth/v2/keys",
                    "userinfo_endpoint": f"{ISSUER}/oidc/v1/userinfo",
                },
            )
        if path == "/oauth/v2/keys":
            self.jwks_calls += 1
            if self.jwks_down:
                return httpx.Response(503)
            keys = []
            for kid, priv in self.published.items():
                jwk = RSAAlgorithm.to_jwk(priv.public_key(), as_dict=True)
                keys.append({**jwk, "kid": kid, "use": "sig", "alg": "RS256"})
            return httpx.Response(200, json={"keys": keys})
        if path == "/oidc/v1/userinfo":
            self.userinfo_calls += 1
            if self.userinfo_down:
                return httpx.Response(503)
            bearer = request.headers.get("authorization", "").split(" ", 1)[-1]
            sub = jwt.decode(bearer, options={"verify_signature": False})["sub"]
            name = self.names.get(sub, f"Nombre de {sub}")
            return httpx.Response(200, json={"sub": sub, "name": name, "email": f"{sub}@x.test"})
        return httpx.Response(404)

    def token(
        self,
        sub: str,
        *,
        kid: str = "k1",
        aud: str = PROJECT_ID,
        iss: str = ISSUER,
        exp_in: int = 900,
        nbf_in: int | None = None,
        signing_key: str | None = None,
    ) -> str:
        now = int(time.time())
        payload = {"sub": sub, "aud": [aud], "iss": iss, "iat": now, "exp": now + exp_in}
        if nbf_in is not None:
            payload["nbf"] = now + nbf_in
        priv = _key(signing_key or kid)
        return jwt.encode(payload, priv, algorithm="RS256", headers={"kid": kid})

    def headers(self, sub: str, **kw) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token(sub, **kw)}"}


@pytest.fixture(scope="session")
def contract() -> dict:
    return yaml.safe_load(SPEC_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="session")
def pg_url():
    with PostgresContainer("postgres:16-alpine", driver=None) as pg:
        yield pg.get_connection_url()


@pytest.fixture(scope="session")
def settings(pg_url, tmp_path_factory) -> Settings:
    return Settings(
        database_url=pg_url,
        oidc_issuer=ISSUER,
        oidc_project_id=PROJECT_ID,
        admin_subject=ADMIN_SUB,
        app_env="test",
        apk_dir=str(tmp_path_factory.mktemp("apk")),
    )


@pytest_asyncio.fixture(scope="session")
async def migrated(settings) -> None:
    await migrate(settings)


@pytest.fixture
def zitadel() -> FakeZitadel:
    return FakeZitadel()


@pytest_asyncio.fixture
async def app(settings, migrated, zitadel):
    application = create_app(settings, oidc_transport=zitadel.transport)
    async with application.state.engine.begin() as conn:
        await conn.execute(
            text(
                "TRUNCATE registration_failure, registration_throttle, "
                "invitation_code, user_account RESTART IDENTITY CASCADE"
            )
        )
    yield application
    await application.state.oidc.aclose()
    await application.state.engine.dispose()


@pytest_asyncio.fixture
async def client(app) -> AsyncIterator[httpx.AsyncClient]:
    transport = httpx.ASGITransport(app=app, raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
def make_account(app):
    async def _make(subject: str, *, status: str = "active", name: str = "Persona") -> UserAccount:
        now = datetime.now(UTC)
        async with app.state.sessionmaker() as s, s.begin():
            acc = UserAccount(
                id=uuid.uuid4(),
                subject=subject,
                display_name=name,
                display_name_synced_at=now,
                status=status,
                created_at=now,
                disabled_at=now if status == "disabled" else None,
            )
            s.add(acc)
        return acc

    return _make


@pytest.fixture
def seed_code(app, make_account):
    """Crea (si falta) la cuenta del administrador e inserta el código vigente."""
    from sqlalchemy import select

    from mykcal.invitations.models import InvitationCode

    async def _seed(code: str = "ABCD2345") -> str:
        async with app.state.sessionmaker() as s:
            admin = (
                await s.execute(select(UserAccount).where(UserAccount.subject == ADMIN_SUB))
            ).scalar_one_or_none()
        if admin is None:
            admin = await make_account(ADMIN_SUB, name="Erick")
        now = datetime.now(UTC)
        async with app.state.sessionmaker() as s, s.begin():
            s.add(InvitationCode(code=code, is_current=True, created_at=now, created_by=admin.id))
        return code

    return _seed
