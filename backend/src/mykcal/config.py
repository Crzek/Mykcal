"""Configuración del backend. Falla al arrancar si falta algo, sin mostrar valores."""

from __future__ import annotations

import base64
import binascii
import ipaddress
from functools import lru_cache
from urllib.parse import parse_qs, urlsplit

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

MAX_ACTIVE_ACCOUNTS = 50


def _host_is_internal(host: str) -> bool:
    """Local, IP privada o nombre de servicio interno (sin puntos)."""
    if host in ("localhost", ""):
        return True
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return "." not in host
    return ip.is_loopback or ip.is_private


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", extra="ignore", case_sensitive=False, hide_input_in_errors=True
    )

    database_url: str = Field(min_length=1)
    oidc_issuer: str = Field(min_length=1)
    oidc_project_id: str = Field(min_length=1)
    admin_subject: str = Field(min_length=1)
    app_env: str = "development"
    apk_dir: str = "/data/apk"
    migration_timeout_s: int = Field(default=120, ge=5, le=900)
    run_migrations: str = "1"
    off_base_url: str = "https://world.openfoodfacts.org"
    off_user_agent: str = "Mykcal/0.3 (app privada)"
    off_timeout_s: float = Field(default=5.0, ge=1, le=30)
    # 006: clave maestra (32 bytes en base64) con la que se cifran las claves de IA de los usuarios.
    ai_key_master: SecretStr
    # 010: preferencia opcional de modelos, separados por comas. Vacía = elección automática.
    ai_model: str = ""
    ai_timeout_s: float = Field(default=55.0, ge=5, le=58)

    @property
    def ai_model_preference(self) -> list[str]:
        names: list[str] = []
        for part in self.ai_model.split(","):
            name = part.strip()
            if name and name not in names:
                names.append(name)
        return names

    @field_validator("ai_key_master")
    @classmethod
    def _master(cls, v: SecretStr) -> SecretStr:
        try:
            ok = len(base64.b64decode(v.get_secret_value(), validate=True)) == 32
        except (binascii.Error, ValueError):
            ok = False
        if not ok:
            raise ValueError("AI_KEY_MASTER debe ser base64 de 32 bytes")
        return v

    @field_validator("off_base_url")
    @classmethod
    def _off_url(cls, v: str) -> str:
        if not v.startswith("https://"):
            raise ValueError("OFF_BASE_URL debe empezar por https://")
        return v.rstrip("/")

    @field_validator("oidc_issuer")
    @classmethod
    def _issuer(cls, v: str) -> str:
        if not v.startswith("https://"):
            raise ValueError("OIDC_ISSUER debe empezar por https://")
        if v.endswith("/"):
            raise ValueError("OIDC_ISSUER no debe terminar en /")
        return v

    @field_validator("app_env")
    @classmethod
    def _env(cls, v: str) -> str:
        if v not in ("production", "development", "test"):
            raise ValueError("APP_ENV debe ser production, development o test")
        return v

    @model_validator(mode="after")
    def _database(self) -> Settings:
        url = self.database_url
        parts = urlsplit(url)
        if parts.scheme not in ("postgresql", "postgres", "postgresql+asyncpg"):
            raise ValueError("DATABASE_URL debe ser una URL de PostgreSQL")
        ssl = parse_qs(parts.query).get("ssl", [""])[0]
        if not _host_is_internal(parts.hostname or "") and ssl != "require":
            raise ValueError("DATABASE_URL con host externo exige ?ssl=require")
        if parts.scheme != "postgresql+asyncpg":
            url = "postgresql+asyncpg://" + url.split("://", 1)[1]
        self.database_url = url
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
