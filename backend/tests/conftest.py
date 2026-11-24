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


@pytest.fixture(scope="session", autouse=True)
def _no_real_open_food_facts():
    """FR-018: ninguna prueba sale a Open Food Facts. Los clientes de OFF usan MockTransport."""
    original = httpx.AsyncHTTPTransport.handle_async_request

    async def guarded(self, request):
        if request.url.host.endswith("openfoodfacts.org"):
            raise AssertionError(
                "Prueba con cliente real de Open Food Facts: inyecta un httpx.MockTransport"
            )
        return await original(self, request)

    httpx.AsyncHTTPTransport.handle_async_request = guarded
    yield
    httpx.AsyncHTTPTransport.handle_async_request = original


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
                "TRUNCATE diary_entry, food, food_import, registration_failure, "
                "registration_throttle, daily_target, weight_entry, user_profile, health_consent, "
                "invitation_code, user_account "
                "RESTART IDENTITY CASCADE"
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
def grant_consent(app):
    """Registra el consentimiento vigente de una cuenta."""
    from mykcal.consent.models import HealthConsent
    from mykcal.consent.service import CURRENT_CONSENT_VERSION

    async def _grant(account: UserAccount) -> None:
        async with app.state.sessionmaker() as s, s.begin():
            s.add(
                HealthConsent(
                    user_id=account.id,
                    text_version=CURRENT_CONSENT_VERSION,
                    accepted_at=datetime.now(UTC),
                )
            )

    return _grant


@pytest.fixture
def profile_body():
    """Cuerpo válido de PUT /v1/profile (ejemplo de la spec: hombre, 30, 180, 80, moderada)."""

    def _body(**overrides) -> dict:
        body = {
            "age": 30,
            "sex": "male",
            "height_cm": 180,
            "weight_kg": 80,
            "activity_level": "moderate",
            "goal": "maintain",
            "measured_on": datetime.now(UTC).date().isoformat(),
        }
        return {**body, **overrides}

    return _body


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


@pytest.fixture
def user_with_consent(make_account, grant_consent, zitadel):
    """Crea una cuenta activa con consentimiento y devuelve (cuenta, cabeceras de autorización)."""

    async def _make(subject: str, *, name: str = "Persona"):
        account = await make_account(subject, name=name)
        await grant_consent(account)
        return account, zitadel.headers(subject)

    return _make


@pytest.fixture
def make_food(app):
    """Inserta un alimento directamente en la base. Devuelve su id."""
    from mykcal.foods.models import Food
    from mykcal.foods.text import normalize

    async def _make(
        name: str,
        *,
        kind: str = "generic",
        owner=None,
        brand: str | None = None,
        barcode: str | None = None,
        base_unit: str = "g",
        synonyms: str | None = None,
        source_code: str | None = None,
        fetched_at: datetime | None = None,
        archived_at: datetime | None = None,
        deleted_at: datetime | None = None,
        serving_size=None,
        **nutrients,
    ) -> uuid.UUID:
        now = datetime.now(UTC)
        values = {"kcal": 100, "protein_g": 10, "carbs_g": 20, "fat_g": 5, **nutrients}
        source = {"generic": "ciqual", "packaged": "off", "custom": "user"}[kind]
        if kind == "generic" and source_code is None:
            source_code = uuid.uuid4().hex[:8]
        if kind == "packaged":
            fetched_at = fetched_at or now
        food = Food(
            id=uuid.uuid4(),
            kind=kind,
            owner_user_id=owner.id if owner is not None else None,
            name=name,
            brand=brand,
            barcode=barcode,
            base_unit=base_unit,
            serving_size=serving_size,
            synonyms=synonyms,
            search_text=normalize(" ".join(p for p in (name, brand, synonyms) if p)),
            source=source,
            source_code=source_code,
            fetched_at=fetched_at,
            archived_at=archived_at,
            deleted_at=deleted_at,
            created_at=now,
            updated_at=now,
            **values,
        )
        async with app.state.sessionmaker() as s, s.begin():
            s.add(food)
        return food.id

    return _make


TARGET_DEFAULTS = {
    "kcal": 2000,
    "protein_g": 150,
    "carbs_g": 200,
    "fat_g": 56,
    "fiber_g": 25,
    "sodium_mg": 2300,
    "potassium_mg": 3500,
    "calcium_mg": 1000,
    "iron_mg": 8,
    "magnesium_mg": 400,
    "vitamin_d_ug": 15,
    "vitamin_c_mg": 90,
}


@pytest.fixture
def make_target_version(app):
    """Inserta una versión de `daily_target`. La nueva pasa a ser la vigente y cierra la anterior.

    Para varias versiones, créalas en orden de `effective_from`.
    """
    from sqlalchemy import update

    from mykcal.targets.models import DailyTarget

    async def _make(account: UserAccount, effective_from: datetime, **values) -> uuid.UUID:
        nutrients = {**TARGET_DEFAULTS, **values}
        row = DailyTarget(
            id=uuid.uuid4(),
            user_id=account.id,
            is_current=True,
            effective_from=effective_from,
            superseded_at=None,
            source="calculated",
            calc_weight_kg=80,
            calc_age=30,
            calc_sex="male",
            calc_height_cm=180,
            calc_activity="moderate",
            calc_goal="maintain",
            calculated_at=effective_from,
            **nutrients,
        )
        async with app.state.sessionmaker() as s, s.begin():
            await s.execute(
                update(DailyTarget)
                .where(DailyTarget.user_id == account.id, DailyTarget.is_current.is_(True))
                .values(is_current=False, superseded_at=effective_from)
            )
            s.add(row)
        return row.id

    return _make


@pytest.fixture
def make_entry(app, make_food):
    """Inserta una entrada del diario copiando el alimento (como hace el servicio)."""
    from datetime import date as date_type

    from sqlalchemy import select

    from mykcal.diary.models import DiaryEntry
    from mykcal.foods.models import Food
    from mykcal.foods.nutrients import NUTRIENTS

    async def _make(
        account: UserAccount,
        day: date_type,
        meal: str = "breakfast",
        food_id: uuid.UUID | None = None,
        *,
        quantity=100,
        servings=None,
        deleted_at: datetime | None = None,
        created_at: datetime | None = None,
        name: str = "Pan",
        **per_100,
    ) -> uuid.UUID:
        if food_id is None:
            food_id = await make_food(name, **per_100)
        async with app.state.sessionmaker() as s:
            food = (await s.execute(select(Food).where(Food.id == food_id))).scalar_one()
        now = created_at or datetime.now(UTC)
        entry = DiaryEntry(
            id=uuid.uuid4(),
            user_id=account.id,
            entry_date=day,
            meal=meal,
            food_id=food.id,
            food_kind=food.kind,
            food_name=food.name,
            food_brand=food.brand,
            base_unit=food.base_unit,
            serving_size=food.serving_size,
            quantity=quantity,
            servings=servings,
            created_at=now,
            updated_at=now,
            deleted_at=deleted_at,
            **{n: getattr(food, n) for n in NUTRIENTS},
        )
        async with app.state.sessionmaker() as s, s.begin():
            s.add(entry)
        return entry.id

    return _make
