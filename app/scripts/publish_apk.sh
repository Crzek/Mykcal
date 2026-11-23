#!/usr/bin/env bash
# Sube el APK al volumen del entorno en el servidor de Dokploy. Uso: scripts/publish_apk.sh <prod|dev>
# Host y rutas van en ~/.config/mykcal/publish.env (fuera del repositorio):
#   PUBLISH_HOST=usuario@servidor
#   PUBLISH_DIR_PROD=/ruta/al/volumen/mykcal-apk
#   PUBLISH_DIR_DEV=/ruta/al/volumen/mykcal-apk-dev
set -euo pipefail
flavor="${1:-}"
case "$flavor" in prod | dev) ;; *) echo "Uso: $0 <prod|dev>" >&2; exit 2 ;; esac
cd "$(dirname "$0")/.."

env_file="${MYKCAL_PUBLISH_ENV:-$HOME/.config/mykcal/publish.env}"
[[ -f "$env_file" ]] || { echo "Falta $env_file" >&2; exit 1; }
# shellcheck disable=SC1090
source "$env_file"

apk="build/app/outputs/flutter-apk/app-${flavor}-release.apk"
[[ -f "$apk" ]] || { echo "No existe $apk: ejecuta scripts/build_apk.sh $flavor" >&2; exit 1; }

if [[ "$flavor" == prod ]]; then dir="${PUBLISH_DIR_PROD:?}"; url="https://mykcal-bk-api.cruzerick.com"; \
else dir="${PUBLISH_DIR_DEV:?}"; url="https://mykcal-bk-dev-api.cruzerick.com"; fi

scp "$apk" "${PUBLISH_HOST:?}:${dir}/mykcal.apk.tmp"
ssh "$PUBLISH_HOST" "mv '${dir}/mykcal.apk.tmp' '${dir}/mykcal.apk'"

status="$(curl -s -o /dev/null -w '%{http_code}' -I "${url}/descargar/mykcal.apk")"
[[ "$status" == 200 ]] || { echo "La descarga responde $status, esperaba 200" >&2; exit 1; }
echo "Publicado: ${url}/descargar/mykcal.apk"
