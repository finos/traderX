#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-005}"
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/messaging-nats-replacement/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[info] compose file not found; nothing to stop: ${COMPOSE_FILE}"
  exit 0
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" down --remove-orphans
echo "[done] state 005 messaging-nats runtime stopped"
