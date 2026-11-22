#!/bin/sh
set -e
if [ "${RUN_MIGRATIONS:-1}" != "0" ]; then
  python -m mykcal.migrate
fi
exec "$@"
