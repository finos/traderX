#!/usr/bin/env bash
set -euo pipefail

STATE_NUMBER="${1:-}"
COMPOSE_FILE="${2:-}"

if [[ -z "${STATE_NUMBER}" || -z "${COMPOSE_FILE}" ]]; then
  echo "usage: bash pipeline/normalize-observability-runtime.sh <state-number> <compose-file>"
  exit 1
fi

if [[ ! "${STATE_NUMBER}" =~ ^[0-9]{3}$ ]]; then
  echo "[fail] invalid state number: ${STATE_NUMBER}"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[fail] compose file not found: ${COMPOSE_FILE}"
  exit 1
fi

DEFAULT_GRAFANA_ADMIN_USER="traderx-admin"
DEFAULT_GRAFANA_ADMIN_PASSWORD="traderx-state-${STATE_NUMBER}"

# Avoid collisions with local dev servers (for example docs) that often use 3000.
perl -0pi -e 's/"3000:3000"/"${GRAFANA_PORT:-3001}:3000"/g' "${COMPOSE_FILE}"

# Public demos should expose read-only dashboards without login while keeping
# administrator access available through non-default, runtime-overridable values.
perl -0pi -e "s/GF_SECURITY_ADMIN_USER:\\s*\"[^\"]*\"/GF_SECURITY_ADMIN_USER: \"\\\${TRADERX_GRAFANA_ADMIN_USER:-${DEFAULT_GRAFANA_ADMIN_USER}}\"/g" "${COMPOSE_FILE}"
perl -0pi -e "s/GF_SECURITY_ADMIN_PASSWORD:\\s*\"[^\"]*\"/GF_SECURITY_ADMIN_PASSWORD: \"\\\${TRADERX_GRAFANA_ADMIN_PASSWORD:-${DEFAULT_GRAFANA_ADMIN_PASSWORD}}\"/g" "${COMPOSE_FILE}"
perl -0pi -e 's/GF_USERS_ALLOW_SIGN_UP:\s*"[^"]*"/GF_USERS_ALLOW_SIGN_UP: "false"/g' "${COMPOSE_FILE}"
perl -0pi -e 's/GF_AUTH_ANONYMOUS_ENABLED:\s*"[^"]*"/GF_AUTH_ANONYMOUS_ENABLED: "\${TRADERX_GRAFANA_ANONYMOUS_ENABLED:-true}"/g' "${COMPOSE_FILE}"

if ! rg -q "GF_AUTH_ANONYMOUS_ORG_ROLE" "${COMPOSE_FILE}"; then
  perl -0pi -e 's/(GF_AUTH_ANONYMOUS_ENABLED:\s*".*"\n)/$1      GF_AUTH_ANONYMOUS_ORG_ROLE: "\${TRADERX_GRAFANA_ANONYMOUS_ORG_ROLE:-Viewer}"\n/' "${COMPOSE_FILE}"
fi

perl -0pi -e 's#GF_SERVER_ROOT_URL:\s*"[^"]*"#GF_SERVER_ROOT_URL: "\${TRADERX_GRAFANA_ROOT_URL:-\%(protocol)s://\%(domain)s/grafana/}"#g' "${COMPOSE_FILE}"
perl -0pi -e 's/GF_SERVER_SERVE_FROM_SUB_PATH:\s*"[^"]*"/GF_SERVER_SERVE_FROM_SUB_PATH: "true"/g' "${COMPOSE_FILE}"

if ! rg -q "GF_SERVER_ROOT_URL" "${COMPOSE_FILE}"; then
  perl -0pi -e 's/(GF_AUTH_ANONYMOUS_ORG_ROLE:\s*".*"\n)/$1      GF_SERVER_ROOT_URL: "\${TRADERX_GRAFANA_ROOT_URL:-\%(protocol)s:\/\/\%(domain)s\/grafana\/}"\n      GF_SERVER_SERVE_FROM_SUB_PATH: "true"\n/' "${COMPOSE_FILE}"
fi

# Promtail uses Docker discovery through the host daemon socket. The start
# harness exports a detected API version, and this default keeps direct compose
# runs on modern Docker engines deterministic.
perl -0pi -e 's/DOCKER_API_VERSION:\s*"[^"]*"/DOCKER_API_VERSION: "\${TRADERX_PROMTAIL_DOCKER_API_VERSION:-1.44}"/g' "${COMPOSE_FILE}"
