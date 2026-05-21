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
STATE_ID="004-containerized-compose-runtime"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-004}"
COMPOSE_DIR="${GENERATED_ROOT}/code/target-generated/containerized-compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
WEB_COMPONENT_DIR="${GENERATED_ROOT}/code/components/web-front-end-angular-specfirst"
WEB_TARGET_DIR="${GENERATED_ROOT}/code/target-generated/web-front-end/angular"
DRY_RUN=0
SKIP_BUILD=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build"
      exit 1
      ;;
  esac
  shift
done

source "${REPO_ROOT}/scripts/lib/generated-state-detection.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required"
  exit 1
fi

if [[ -z "${DOCKER_BUILDKIT:-}" ]]; then
  export DOCKER_BUILDKIT=1
  echo "[info] DOCKER_BUILDKIT not set; defaulting to 1 for Docker cache mounts"
fi

if [[ "${TRADERX_SKIP_GENERATE:-0}" != "1" ]]; then
  traderx_report_generated_state "${STATE_ID}" "${GENERATED_ROOT}" || true
  bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
else
  echo "[info] skipping state generation for ${STATE_ID} (TRADERX_SKIP_GENERATE=1)"
  traderx_ensure_generated_state "${STATE_ID}" "${REPO_ROOT}" "${GENERATED_ROOT}"
fi

sync_state_aware_web_ui() {
  if [[ ! -d "${WEB_COMPONENT_DIR}" || ! -d "${WEB_TARGET_DIR}" ]]; then
    return 0
  fi

  local rel
  for rel in \
    "main/app/about" \
    "main/app/status" \
    "main/app/model/state-ui-metadata.model.ts" \
    "main/app/service/state-metadata.service.ts" \
    "main/app/header/header.component.ts" \
    "main/app/header/header.component.html" \
    "main/app/header/header.component.scss" \
    "main/app/routing.ts" \
    "main/assets/state-ui.json"; do
    if [[ -d "${WEB_COMPONENT_DIR}/${rel}" ]]; then
      rm -rf "${WEB_TARGET_DIR:?}/${rel}"
      mkdir -p "${WEB_TARGET_DIR}/${rel}"
      cp -R "${WEB_COMPONENT_DIR}/${rel}/." "${WEB_TARGET_DIR}/${rel}/"
    elif [[ -f "${WEB_COMPONENT_DIR}/${rel}" ]]; then
      mkdir -p "$(dirname "${WEB_TARGET_DIR}/${rel}")"
      cp "${WEB_COMPONENT_DIR}/${rel}" "${WEB_TARGET_DIR}/${rel}"
    fi
  done

  echo "[info] synced state-aware About/Status UI sources into containerized web target"
}

sync_state_aware_web_ui

[[ -f "${COMPOSE_FILE}" ]] || {
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
}

if (( DRY_RUN == 1 )); then
  if (( SKIP_BUILD == 1 )); then
    echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --no-build"
  else
    echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --build"
  fi
  echo "[done] dry run complete for state 004"
  exit 0
fi

if (( SKIP_BUILD == 1 )); then
  docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --no-build
else
  docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --build
fi

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts=90
  local i
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "[ready] ${name} ${url}"
      return 0
    fi
    sleep 2
  done
  echo "[error] timeout waiting for ${name} at ${url}"
  return 1
}

wait_for_http "database-web" "http://localhost:18084" || exit 1
wait_for_http "reference-data" "http://localhost:18085/stocks" || exit 1
wait_for_http "account-service" "http://localhost:18088/account/22214" || exit 1
wait_for_http "position-service" "http://localhost:18090/positions/22214" || exit 1
wait_for_http "trade-service" "http://localhost:18092/v3/api-docs" || exit 1
wait_for_http "ingress" "http://localhost:8080/health" || exit 1
wait_for_http "ingress-ui" "http://localhost:8080" || exit 1

echo "[done] state 004 containerized compose runtime started"
echo "[ui] http://localhost:8080"
echo "[api-explorer] http://localhost:8080/api/docs"
