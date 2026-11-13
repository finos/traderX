#!/usr/bin/env bash
set -euo pipefail

STATE_ID="004-containerized-compose-runtime"
TRADERX_WORKDIR="${TRADERX_WORKDIR:-${HOME}/traderx}"
TRADERX_COMPOSE_PATH_REL="${TRADERX_COMPOSE_PATH_REL:-containerized-compose/docker-compose.yml}"
TRADERX_COMPOSE_PROJECT_NAME="${TRADERX_COMPOSE_PROJECT_NAME:-traderx-${STATE_ID}}"
TRADERX_PRUNE_DOCKER="${TRADERX_PRUNE_DOCKER:-0}"
DRY_RUN=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "[fail] unknown argument: $1"
      echo "[hint] supported: --dry-run"
      exit 1
      ;;
  esac
  shift
done

run_cmd() {
  echo "[run] $*"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  "$@"
}

compose_file="${TRADERX_WORKDIR}/${TRADERX_COMPOSE_PATH_REL}"
if [[ -f "${compose_file}" ]]; then
  run_cmd docker compose -f "${compose_file}" --project-name "${TRADERX_COMPOSE_PROJECT_NAME}" down --remove-orphans
else
  echo "[info] compose file not found; skipping compose down: ${compose_file}"
fi

if [[ "${TRADERX_PRUNE_DOCKER}" == "1" ]]; then
  run_cmd docker system prune -f
  run_cmd docker volume prune -f
fi

echo "[done] cleanup completed for state ${STATE_ID}"
