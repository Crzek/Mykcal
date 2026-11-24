#!/bin/sh
set -e
if [ "${RUN_MIGRATIONS:-1}" != "0" ]; then
  python -m mykcal.migrate
  # Alimentos genéricos (003): idempotente. Si falla, queda registrado como
  # generic_import_failed y la API arranca igualmente con los datos anteriores.
  python -m mykcal.foods.load_generic || true
fi
exec "$@"
