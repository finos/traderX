#!/usr/bin/env bash
set -euo pipefail

STATE_ID="009-order-management-matcher"
TRADERX_REPO_URL="${TRADERX_REPO_URL:-https://github.com/finos/traderX.git}"
TRADERX_BRANCH="${TRADERX_BRANCH:-code/generated-state-009-order-management-matcher}"
TRADERX_WORKDIR="${TRADERX_WORKDIR:-${HOME}/traderx}"
TRADERX_COMPOSE_PATH_REL="${TRADERX_COMPOSE_PATH_REL:-order-management-matcher/docker-compose.yml}"
TRADERX_GHCR_COMPOSE_PATH_REL="${TRADERX_GHCR_COMPOSE_PATH_REL:-runtime/ghcr/${STATE_ID}/docker-compose.ghcr.yml}"
TRADERX_COMPOSE_PROJECT_NAME="${TRADERX_COMPOSE_PROJECT_NAME:-traderx-${STATE_ID}}"
TRADERX_DEPLOY_ENV="${TRADERX_DEPLOY_ENV:-demo-advanced}"
TRADERX_FQDN="${TRADERX_FQDN:-demo-advanced.traderx.finos.org}"
TRADERX_IMAGE_TAG="${TRADERX_IMAGE_TAG:-latest}"
TRADERX_CORS_ALLOWED_ORIGINS="${TRADERX_CORS_ALLOWED_ORIGINS:-https://${TRADERX_FQDN},http://${TRADERX_FQDN},http://localhost:8080}"
DRY_RUN=0
USE_GHCR=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --use-ghcr)
      USE_GHCR=1
      ;;
    *)
      echo "[fail] unknown argument: $1"
      echo "[hint] supported: --dry-run --use-ghcr"
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${TRADERX_FQDN}" ]]; then
  echo "[fail] TRADERX_FQDN is required for deploy"
  exit 1
fi

run_cmd() {
  echo "[run] $*"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  "$@"
}

run_compose_up() {
  local compose_file="$1"
  echo "[run] TRADERX_FQDN=${TRADERX_FQDN} TRADERX_IMAGE_TAG=${TRADERX_IMAGE_TAG} TRADERX_CORS_ALLOWED_ORIGINS=${TRADERX_CORS_ALLOWED_ORIGINS} docker compose -f ${compose_file} --project-name ${TRADERX_COMPOSE_PROJECT_NAME} up -d --build"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  TRADERX_FQDN="${TRADERX_FQDN}" TRADERX_IMAGE_TAG="${TRADERX_IMAGE_TAG}" CORS_ALLOWED_ORIGINS="${TRADERX_CORS_ALLOWED_ORIGINS}" \
    docker compose -f "${compose_file}" --project-name "${TRADERX_COMPOSE_PROJECT_NAME}" up -d --build
}

run_compose_ghcr_up() {
  local ghcr_compose_file="$1"
  echo "[run] TRADERX_CORS_ALLOWED_ORIGINS=${TRADERX_CORS_ALLOWED_ORIGINS} docker compose -f ${ghcr_compose_file} --project-name ${TRADERX_COMPOSE_PROJECT_NAME} pull"
  echo "[run] TRADERX_CORS_ALLOWED_ORIGINS=${TRADERX_CORS_ALLOWED_ORIGINS} docker compose -f ${ghcr_compose_file} --project-name ${TRADERX_COMPOSE_PROJECT_NAME} up -d"
  if (( DRY_RUN == 1 )); then
    return 0
  fi
  CORS_ALLOWED_ORIGINS="${TRADERX_CORS_ALLOWED_ORIGINS}" docker compose -f "${ghcr_compose_file}" --project-name "${TRADERX_COMPOSE_PROJECT_NAME}" pull
  CORS_ALLOWED_ORIGINS="${TRADERX_CORS_ALLOWED_ORIGINS}" docker compose -f "${ghcr_compose_file}" --project-name "${TRADERX_COMPOSE_PROJECT_NAME}" up -d
}

if [[ ! -d "${TRADERX_WORKDIR}/.git" ]]; then
  run_cmd git clone "${TRADERX_REPO_URL}" "${TRADERX_WORKDIR}"
fi

run_cmd git -C "${TRADERX_WORKDIR}" fetch --all --prune
run_cmd git -C "${TRADERX_WORKDIR}" checkout "${TRADERX_BRANCH}"
run_cmd git -C "${TRADERX_WORKDIR}" reset --hard "origin/${TRADERX_BRANCH}"

compose_file="${TRADERX_WORKDIR}/${TRADERX_COMPOSE_PATH_REL}"
ghcr_compose_file="${TRADERX_WORKDIR}/${TRADERX_GHCR_COMPOSE_PATH_REL}"
if (( USE_GHCR == 1 )); then
  if [[ ! -f "${ghcr_compose_file}" ]]; then
    if (( DRY_RUN == 1 )); then
      echo "[warn] GHCR compose file not found in dry-run mode: ${ghcr_compose_file}"
    else
      echo "[fail] GHCR compose file not found: ${ghcr_compose_file}"
      exit 1
    fi
  fi
else
  if [[ ! -f "${compose_file}" ]]; then
    if (( DRY_RUN == 1 )); then
      echo "[warn] compose file not found in dry-run mode: ${compose_file}"
    else
      echo "[fail] compose file not found: ${compose_file}"
      exit 1
    fi
  fi
fi

if (( USE_GHCR == 1 )); then
  run_compose_ghcr_up "${ghcr_compose_file}"
  echo "[done] deploy completed for state ${STATE_ID} (${TRADERX_DEPLOY_ENV}) using ghcr images"
else
  run_compose_up "${compose_file}"
  echo "[done] deploy completed for state ${STATE_ID} (${TRADERX_DEPLOY_ENV}) using local builds"
fi
