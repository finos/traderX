#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-007}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/observability-lgtm-compose/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[info] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 007-observability-lgtm-compose"
  exit 0
fi

echo "[info] compose project: ${COMPOSE_PROJECT_NAME}"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps

http_code_for() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true
}

printf "\n%-28s %-8s %s\n" "endpoint" "http" "url"
printf "%-28s %-8s %s\n" "----------------------------" "--------" "---"

for target in \
  "ingress-health|http://localhost:8080/health" \
  "ingress-ui|http://localhost:8080/" \
  "grafana|http://localhost:${GRAFANA_PORT}/api/health" \
  "prometheus|http://localhost:9090/-/ready" \
  "loki|http://localhost:3100/ready" \
  "tempo|http://localhost:3200/ready" \
  "otel-collector|http://localhost:13133/" \
  "reference-data|http://localhost:18085/stocks" \
  "account-service|http://localhost:18088/account/22214" \
  "position-service|http://localhost:18090/health/alive" \
  "trade-service|http://localhost:18092/v3/api-docs"; do
  name="${target%%|*}"
  url="${target#*|}"
  code="$(http_code_for "${url}")"
  printf "%-28s %-8s %s\n" "${name}" "${code:-000}" "${url}"
done
