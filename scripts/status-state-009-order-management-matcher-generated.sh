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
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-009}"
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/order-management-matcher/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[info] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 009-order-management-matcher"
  exit 0
fi

echo "[info] compose project: ${COMPOSE_PROJECT_NAME}"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps

http_code_for() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true
}

printf "\n%-30s %-8s %s\n" "endpoint" "http" "url"
printf "%-30s %-8s %s\n" "------------------------------" "--------" "---"

for target in \
  "ingress-health|http://localhost:8080/health" \
  "ingress-ui|http://localhost:8080/" \
  "order-matcher-health|http://localhost:18110/health" \
  "order-matcher-metrics|http://localhost:18110/metrics" \
  "price-publisher|http://localhost:18100/health" \
  "nats-monitor|http://localhost:8222/varz" \
  "grafana|http://localhost:3000/api/health" \
  "prometheus|http://localhost:9090/-/ready" \
  "loki|http://localhost:3100/ready" \
  "tempo|http://localhost:3200/ready" \
  "otel-collector|http://localhost:13133/" \
  "trade-service|http://localhost:18092/swagger-ui.html" \
  "position-service|http://localhost:18090/health/alive"; do
  name="${target%%|*}"
  url="${target#*|}"
  code="$(http_code_for "${url}")"
  printf "%-30s %-8s %s\n" "${name}" "${code:-000}" "${url}"
done
