#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-007}"
COMPOSE_FILE="${REPO_ROOT}/generated/code/target-generated/messaging-nats-replacement/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[info] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 007-messaging-nats-replacement"
  exit 0
fi

echo "[info] compose project: ${COMPOSE_PROJECT_NAME}"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps

http_code_for() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true
}

printf "\n%-24s %-8s %s\n" "endpoint" "http" "url"
printf "%-24s %-8s %s\n" "------------------------" "--------" "---"

for target in \
  "ingress-health|http://localhost:8080/health" \
  "ingress-ui|http://localhost:8080/" \
  "angular-ui|http://localhost:18093/" \
  "reference-data|http://localhost:18085/stocks" \
  "account-service|http://localhost:18088/account/22214" \
  "position-service|http://localhost:18090/health/alive" \
  "trade-service|http://localhost:18092/swagger-ui.html" \
  "nats-monitor|http://localhost:8222/varz"; do
  name="${target%%|*}"
  url="${target#*|}"
  code="$(http_code_for "${url}")"
  printf "%-24s %-8s %s\n" "${name}" "${code:-000}" "${url}"
done
