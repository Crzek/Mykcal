#!/usr/bin/env bash
# Compila el APK de release firmado de un sabor. Uso: scripts/build_apk.sh <prod|dev>
set -euo pipefail
flavor="${1:-}"
case "$flavor" in prod | dev) ;; *) echo "Uso: $0 <prod|dev>" >&2; exit 2 ;; esac
cd "$(dirname "$0")/.."

if [[ ! -f android/key.properties ]]; then
  echo "Falta android/key.properties (storeFile, storePassword, keyAlias, keyPassword)." >&2
  echo "El keystore vive fuera del repositorio: ~/.keystores/mykcal-release.jks" >&2
  exit 1
fi
if grep -q '""' "config/${flavor}.json" || grep -Eq '"OIDC_(ORG_ID|PROJECT_ID|CLIENT_ID)": *""' "config/${flavor}.json"; then
  echo "config/${flavor}.json tiene OIDC_ORG_ID, OIDC_PROJECT_ID u OIDC_CLIENT_ID vacíos." >&2
  exit 1
fi

flutter build apk --release --flavor "$flavor" --dart-define-from-file="config/${flavor}.json"
echo "APK: build/app/outputs/flutter-apk/app-${flavor}-release.apk"
