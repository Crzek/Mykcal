# Mykcal

Registro de comidas y calorías para un círculo cercano (máx. 50 usuarios). Monorepo:

- `backend/`: API FastAPI + PostgreSQL (Python 3.12, `uv`).
- `app/`: app Flutter solo para Android, con sabores `prod` y `dev`.
- `specs/`: especificaciones Spec Kit (una carpeta por feature). La constitución está en
  `.specify/memory/constitution.md`.

Ramas: `main` = producción, `dev` = desarrollo; cada feature nace de `dev`.

## Backend

```bash
cd backend
docker compose -f docker-compose.dev.yml up -d   # PostgreSQL local
cp .env.example .env                             # rellena OIDC_PROJECT_ID y ADMIN_SUBJECT
uv sync
uv run pytest                                    # necesita Docker (testcontainers)
uv run pytest -m privacy                         # reglas de privacidad y aislamiento
uv run python -m mykcal.migrate                  # migraciones
uv run uvicorn mykcal.main:create_app --factory --reload
```

## App

```bash
cd app
flutter test
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

`config/dev.json` y `config/prod.json` llevan `OIDC_ORG_ID`, `OIDC_PROJECT_ID` y
`OIDC_CLIENT_ID` (no son secretos) que se rellenan al configurar Zitadel
(`specs/001-acceso-y-despliegue/contracts/zitadel-setup.md`).

## APK

1. Crea el keystore de release fuera del repositorio (`~/.keystores/mykcal-release.jks`) y
   `app/android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`).
2. `app/scripts/build_apk.sh <prod|dev>` compila y firma.
3. `app/scripts/publish_apk.sh <prod|dev>` lo sube al volumen del servidor; se descarga en
   `https://<api>/descargar/mykcal.apk` (host y rutas en `~/.config/mykcal/publish.env`).

## Despliegue

Dokploy, un entorno por rama: ver `specs/001-acceso-y-despliegue/contracts/dokploy-setup.md`.
